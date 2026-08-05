"""Importing many accounts at once.

Handles both a loose pile of `.maFile` documents and a `.zip` of an entire SDA
`maFiles` directory. The archive case is the useful one: if it contains the
`manifest.json` alongside encrypted files, the per-entry salt and IV needed to
decrypt them are right there, which a single uploaded file can never carry.
"""

from __future__ import annotations

import io
import json
import logging
import zipfile
from dataclasses import dataclass, field

from . import file_encryptor
from .models import SteamGuardAccount
from .storage import AccountStore

log = logging.getLogger(__name__)

# Bounds on what an archive may expand to. An import is triggered by anyone the
# admin trusts, but a malformed or hostile zip should fail loudly rather than
# exhaust memory.
MAX_ARCHIVE_ENTRIES = 500
MAX_UNCOMPRESSED_BYTES = 64 * 1024 * 1024
MAX_MEMBER_BYTES = 1024 * 1024


@dataclass
class ImportOutcome:
    filename: str
    ok: bool
    account_name: str | None = None
    steam_id: int | None = None
    error: str | None = None


@dataclass
class ImportReport:
    outcomes: list[ImportOutcome] = field(default_factory=list)

    @property
    def imported(self) -> list[ImportOutcome]:
        return [o for o in self.outcomes if o.ok]

    @property
    def failed(self) -> list[ImportOutcome]:
        return [o for o in self.outcomes if not o.ok]

    @property
    def needed_passkey(self) -> bool:
        """Whether anything failed specifically because it was encrypted."""
        return any(o.error == _ENCRYPTED_ERROR for o in self.failed)

    def __len__(self) -> int:
        return len(self.outcomes)


_ENCRYPTED_ERROR = "encrypted — supply the passkey"


async def import_mafiles(
    store: AccountStore,
    files: list[tuple[str, bytes]],
    passkey: str | None = None,
    encryption_map: dict[str, tuple[str, str]] | None = None,
) -> ImportReport:
    """Import each ``(filename, raw_bytes)`` pair, collecting per-file results.

    ``encryption_map`` maps a filename to its (salt, iv) from a manifest, which
    is what makes decrypting an archived account possible.
    """
    report = ImportReport()
    encryption_map = encryption_map or {}

    for filename, raw in files:
        try:
            account = _parse(filename, raw, passkey, encryption_map)
            await store.save_account(account)
            report.outcomes.append(
                ImportOutcome(
                    filename=filename,
                    ok=True,
                    account_name=account.display_name,
                    steam_id=account.steam_id,
                )
            )
        except ValueError as exc:
            report.outcomes.append(
                ImportOutcome(filename=filename, ok=False, error=str(exc))
            )
        except Exception as exc:  # noqa: BLE001 - one bad file must not stop the rest
            log.exception("Unexpected failure importing %s", filename)
            report.outcomes.append(
                ImportOutcome(filename=filename, ok=False, error=str(exc))
            )

    return report


async def import_archive(
    store: AccountStore, archive: bytes, passkey: str | None = None
) -> ImportReport:
    """Import every `.maFile` in a zip, honouring its manifest.json if present."""
    try:
        zip_file = zipfile.ZipFile(io.BytesIO(archive))
    except (zipfile.BadZipFile, OSError) as exc:
        raise ValueError("That is not a readable .zip archive.") from exc

    with zip_file:
        members = [m for m in zip_file.infolist() if not m.is_dir()]

        if len(members) > MAX_ARCHIVE_ENTRIES:
            raise ValueError(
                f"That archive has {len(members)} entries; the limit is "
                f"{MAX_ARCHIVE_ENTRIES}."
            )

        total = sum(m.file_size for m in members)
        if total > MAX_UNCOMPRESSED_BYTES:
            raise ValueError("That archive expands to too much data.")

        encryption_map = _encryption_map(zip_file, members)
        files = _read_mafiles(zip_file, members)

    if not files:
        raise ValueError("No .maFile entries found in that archive.")

    return await import_mafiles(store, files, passkey, encryption_map)


def _read_mafiles(
    zip_file: zipfile.ZipFile, members: list[zipfile.ZipInfo]
) -> list[tuple[str, bytes]]:
    files: list[tuple[str, bytes]] = []

    for member in members:
        name = member.filename.rsplit("/", 1)[-1]
        if not name.lower().endswith(".mafile"):
            continue
        if member.file_size > MAX_MEMBER_BYTES:
            log.warning("Skipping oversized archive member %s", name)
            continue

        try:
            files.append((name, zip_file.read(member)))
        except (zipfile.BadZipFile, OSError, RuntimeError) as exc:
            log.warning("Could not read %s from archive: %s", name, exc)

    return files


def _encryption_map(
    zip_file: zipfile.ZipFile, members: list[zipfile.ZipInfo]
) -> dict[str, tuple[str, str]]:
    """Pull per-file salt and IV out of an archived manifest.json."""
    manifest_member = next(
        (
            m
            for m in members
            if m.filename.rsplit("/", 1)[-1].lower() == "manifest.json"
            and m.file_size <= MAX_MEMBER_BYTES
        ),
        None,
    )
    if manifest_member is None:
        return {}

    try:
        data = json.loads(zip_file.read(manifest_member).decode("utf-8"))
    except (ValueError, UnicodeDecodeError, OSError) as exc:
        log.warning("Archive manifest.json is unreadable: %s", exc)
        return {}

    mapping: dict[str, tuple[str, str]] = {}
    for entry in data.get("entries") or []:
        filename = entry.get("filename")
        salt = entry.get("encryption_salt")
        iv = entry.get("encryption_iv")
        if filename and salt and iv:
            mapping[filename.rsplit("/", 1)[-1]] = (salt, iv)

    return mapping


def _parse(
    filename: str,
    raw: bytes,
    passkey: str | None,
    encryption_map: dict[str, tuple[str, str]],
) -> SteamGuardAccount:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("not readable text") from exc

    crypto = encryption_map.get(filename)
    if crypto is not None:
        if not passkey:
            raise ValueError(_ENCRYPTED_ERROR)

        salt, iv = crypto
        decrypted = file_encryptor.decrypt_data(passkey, salt, iv, text.strip())
        if decrypted is None:
            raise ValueError("wrong passkey")
        text = decrypted

    try:
        data = json.loads(text)
    except ValueError as exc:
        # No manifest entry and not JSON: almost certainly encrypted, and
        # without a manifest its salt and IV are unrecoverable.
        raise ValueError(
            _ENCRYPTED_ERROR
            if crypto is None and passkey is None
            else "not valid JSON"
        ) from exc

    if not isinstance(data, dict):
        raise ValueError("not a maFile")

    account = SteamGuardAccount.from_json(data)
    if not account.shared_secret:
        raise ValueError("no shared_secret")
    if not account.steam_id:
        raise ValueError("no Session.SteamID")

    return account
