"""Account storage in the desktop app's maFiles layout.

The on-disk shape is deliberately identical to the Flutter app and the original
C# SDA — `manifest.json` plus one `{steamid}.maFile` per account — so accounts
move between the app and this bot by copying files, and `/import` accepts a
maFile exported from either.

Encryption is opt-in via ``passkey``. With one set, every .maFile is
AES-256-CBC encrypted with a per-entry salt and IV, exactly as the app does it.
"""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path

from . import file_encryptor
from .models import Manifest, ManifestEntry, SteamGuardAccount

log = logging.getLogger(__name__)


class WrongPasskeyError(Exception):
    """Raised when stored accounts cannot be decrypted with the configured key."""


class AccountStore:
    """Loads and persists Steam Guard accounts.

    Disk work runs on a worker thread: key derivation is 50,000 PBKDF2 rounds
    per account, which is long enough to stall the event loop if done inline.
    """

    def __init__(self, data_dir: Path, passkey: str | None = None) -> None:
        self._dir = Path(data_dir)
        self._passkey = passkey or None
        self._manifest = Manifest()
        self._accounts: dict[int, SteamGuardAccount] = {}
        self._lock = asyncio.Lock()

    @property
    def manifest_path(self) -> Path:
        return self._dir / "manifest.json"

    @property
    def encryption_enabled(self) -> bool:
        return self._passkey is not None

    # ── Loading ──────────────────────────────────────────────────────────

    async def load(self) -> None:
        """Read the manifest and every account into memory."""
        async with self._lock:
            await asyncio.to_thread(self._load_sync)
        log.info(
            "Loaded %d account(s) from %s (encrypted=%s)",
            len(self._accounts),
            self._dir,
            self._manifest.encrypted,
        )

    def _load_sync(self) -> None:
        self._dir.mkdir(parents=True, exist_ok=True)

        if self.manifest_path.exists():
            try:
                raw = json.loads(self.manifest_path.read_text("utf-8"))
                self._manifest = Manifest.from_json(raw)
            except (OSError, ValueError) as exc:
                raise RuntimeError(f"manifest.json is unreadable: {exc}") from exc
        else:
            self._manifest = Manifest()
            self._write_manifest()

        if self._manifest.encrypted and not self._passkey:
            raise WrongPasskeyError(
                "Stored accounts are encrypted but SDA_PASSKEY is not set."
            )

        self._accounts.clear()
        # Drop entries whose backing file vanished, as the desktop app does.
        surviving: list[ManifestEntry] = []

        for entry in self._manifest.entries:
            path = self._dir / entry.filename
            if not path.exists():
                log.warning("Manifest references missing file %s", entry.filename)
                continue

            account = self._read_account(path, entry)
            if account is None:
                raise WrongPasskeyError(
                    f"Could not decrypt {entry.filename}. Is SDA_PASSKEY correct?"
                )

            surviving.append(entry)
            self._accounts[account.steam_id or entry.steam_id] = account

        if len(surviving) != len(self._manifest.entries):
            self._manifest.entries = surviving
            self._write_manifest()

    def _read_account(
        self, path: Path, entry: ManifestEntry
    ) -> SteamGuardAccount | None:
        text = path.read_text("utf-8")

        if self._manifest.encrypted:
            if not entry.salt or not entry.iv:
                return None
            text = file_encryptor.decrypt_data(
                self._passkey, entry.salt, entry.iv, text
            )
            if text is None:
                return None

        try:
            return SteamGuardAccount.from_json(json.loads(text))
        except ValueError:
            return None

    # ── Reading ──────────────────────────────────────────────────────────

    def all_accounts(self) -> list[SteamGuardAccount]:
        return sorted(self._accounts.values(), key=lambda a: a.display_name.lower())

    def get(self, steam_id: int) -> SteamGuardAccount | None:
        return self._accounts.get(steam_id)

    def __len__(self) -> int:
        return len(self._accounts)

    # ── Writing ──────────────────────────────────────────────────────────

    async def save_account(self, account: SteamGuardAccount) -> None:
        """Persist one account, adding or replacing its manifest entry."""
        if not account.steam_id:
            raise ValueError("Account has no SteamID; cannot be saved.")

        async with self._lock:
            self._accounts[account.steam_id] = account
            await asyncio.to_thread(self._write_account, account)

    def _write_account(self, account: SteamGuardAccount) -> None:
        filename = f"{account.steam_id}.maFile"
        payload = json.dumps(account.to_json())

        salt = iv = None
        if self._passkey:
            salt = file_encryptor.get_random_salt()
            iv = file_encryptor.get_initialization_vector()
            payload = file_encryptor.encrypt_data(self._passkey, salt, iv, payload)

        # Write to a temp file then swap, so a crash mid-write cannot leave a
        # truncated .maFile — which for an encrypted account is unrecoverable.
        target = self._dir / filename
        tmp = target.with_suffix(".maFile.tmp")
        tmp.write_text(payload, "utf-8")
        tmp.replace(target)

        new_entry = ManifestEntry(
            steam_id=account.steam_id, filename=filename, salt=salt, iv=iv
        )
        for index, entry in enumerate(self._manifest.entries):
            if entry.steam_id == account.steam_id:
                self._manifest.entries[index] = new_entry
                break
        else:
            self._manifest.entries.append(new_entry)

        self._manifest.encrypted = self._passkey is not None
        self._manifest.first_run = False
        self._write_manifest()

    async def remove_account(self, steam_id: int) -> bool:
        async with self._lock:
            if steam_id not in self._accounts:
                return False
            self._accounts.pop(steam_id)
            await asyncio.to_thread(self._remove_sync, steam_id)
            return True

    def _remove_sync(self, steam_id: int) -> None:
        remaining = []
        for entry in self._manifest.entries:
            if entry.steam_id == steam_id:
                (self._dir / entry.filename).unlink(missing_ok=True)
            else:
                remaining.append(entry)

        self._manifest.entries = remaining
        if not remaining:
            self._manifest.encrypted = False
        self._write_manifest()

    def _write_manifest(self) -> None:
        tmp = self.manifest_path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(self._manifest.to_json(), indent=2), "utf-8")
        tmp.replace(self.manifest_path)

    # ── Import / export ──────────────────────────────────────────────────

    async def import_mafile(
        self, raw: bytes, passkey: str | None = None
    ) -> SteamGuardAccount:
        """Import a .maFile, optionally decrypting it with its own passkey.

        ``passkey`` is for files exported encrypted from elsewhere; it is
        unrelated to this bot's storage key, which is applied on save.
        """
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("That file is not a readable .maFile.") from exc

        try:
            data = json.loads(text)
        except ValueError as exc:
            if passkey:
                raise ValueError(
                    "Could not read that file. Encrypted maFiles need their "
                    "salt and IV from the source manifest.json, which a single "
                    "file does not carry — decrypt it in the app first."
                ) from exc
            raise ValueError(
                "That file is not valid JSON. If it is encrypted, decrypt it "
                "in the desktop app before importing."
            ) from exc

        account = SteamGuardAccount.from_json(data)
        if not account.shared_secret:
            raise ValueError("That maFile has no shared_secret.")
        if not account.steam_id:
            raise ValueError("That maFile has no Session.SteamID.")

        await self.save_account(account)
        return account

    def export_mafile(self, steam_id: int) -> bytes | None:
        """Serialise an account as a plaintext .maFile for the admin."""
        account = self._accounts.get(steam_id)
        if account is None:
            return None
        return json.dumps(account.to_json(), indent=2).encode("utf-8")
