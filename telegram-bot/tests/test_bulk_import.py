"""Bulk import: many loose maFiles, or a zip of a whole maFiles folder."""

from __future__ import annotations

import io
import json
import zipfile

import pytest

from steamguard import AccountStore, file_encryptor, import_archive, import_mafiles
from steamguard.bulk_import import MAX_ARCHIVE_ENTRIES

SALT = "AQIDBAUGBwg="
IV = "AQIDBAUGBwgJCgsMDQ4PEA=="


def make_mafile(steam_id: int, name: str) -> dict:
    return {
        "shared_secret": "AQIDBAUGBwgJCgsMDQ4PEBESExQ=",
        "identity_secret": "FBUWFxgZGhscHR4fICEiIyQlJic=",
        "account_name": name,
        "device_id": "android:11111111-2222-3333-4444-555555555555",
        "Session": {
            "SteamID": steam_id,
            "AccessToken": "a.b.c",
            "RefreshToken": "a.b.c",
            "SessionID": "0" * 32,
        },
    }


def build_zip(
    members: dict[str, bytes], manifest: dict | None = None
) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        if manifest is not None:
            archive.writestr("manifest.json", json.dumps(manifest))
        for name, payload in members.items():
            archive.writestr(name, payload)
    return buffer.getvalue()


def plain_zip(count: int, prefix: str = "") -> bytes:
    members = {
        f"{prefix}{76561198000000000 + i}.maFile": json.dumps(
            make_mafile(76561198000000000 + i, f"user{i}")
        ).encode()
        for i in range(count)
    }
    return build_zip(members)


@pytest.fixture
async def store(tmp_path) -> AccountStore:
    store = AccountStore(tmp_path)
    await store.load()
    return store


class TestImportMafiles:
    async def test_imports_several_loose_files(self, store):
        files = [
            (
                f"{76561198000000000 + i}.maFile",
                json.dumps(make_mafile(76561198000000000 + i, f"u{i}")).encode(),
            )
            for i in range(5)
        ]

        report = await import_mafiles(store, files)

        assert len(report.imported) == 5
        assert not report.failed
        assert len(store) == 5

    async def test_one_bad_file_does_not_stop_the_others(self, store):
        files = [
            ("good.maFile", json.dumps(make_mafile(1, "good")).encode()),
            ("broken.maFile", b"{ not json"),
            ("also-good.maFile", json.dumps(make_mafile(2, "also")).encode()),
        ]

        report = await import_mafiles(store, files)

        assert len(report.imported) == 2
        assert len(report.failed) == 1
        assert report.failed[0].filename == "broken.maFile"

    async def test_reports_why_each_file_was_rejected(self, store):
        files = [
            ("no-secret.maFile", json.dumps({"account_name": "x"}).encode()),
            (
                "no-steamid.maFile",
                json.dumps({"shared_secret": "abc"}).encode(),
            ),
            ("binary.maFile", b"\xff\xfe\x00\x01"),
        ]

        report = await import_mafiles(store, files)
        errors = {o.filename: o.error for o in report.failed}

        assert "shared_secret" in errors["no-secret.maFile"]
        assert "SteamID" in errors["no-steamid.maFile"]
        assert errors["binary.maFile"]

    async def test_reimporting_replaces_rather_than_duplicates(self, store):
        payload = json.dumps(make_mafile(77, "first")).encode()
        await import_mafiles(store, [("77.maFile", payload)])

        updated = json.dumps(make_mafile(77, "renamed")).encode()
        await import_mafiles(store, [("77.maFile", updated)])

        assert len(store) == 1
        assert store.get(77).account_name == "renamed"


class TestImportArchive:
    async def test_imports_every_mafile_in_a_zip(self, store):
        report = await import_archive(store, plain_zip(12))

        assert len(report.imported) == 12
        assert len(store) == 12

    async def test_handles_a_nested_folder(self, store):
        """A zip made from the folder itself, not its contents."""
        report = await import_archive(store, plain_zip(3, prefix="maFiles/"))

        assert len(report.imported) == 3

    async def test_ignores_unrelated_files(self, store):
        archive = build_zip(
            {
                "76561198000000001.maFile": json.dumps(
                    make_mafile(76561198000000001, "real")
                ).encode(),
                "notes.txt": b"hello",
                "picture.png": b"\x89PNG\r\n",
            }
        )

        report = await import_archive(store, archive)

        assert len(report.imported) == 1
        assert not report.failed

    async def test_decrypts_using_the_archived_manifest(self, store):
        """The case a lone .maFile cannot cover: salt and IV come from the
        manifest that shipped alongside it."""
        steam_id = 76561198000000009
        plaintext = json.dumps(make_mafile(steam_id, "encrypted-user"))
        ciphertext = file_encryptor.encrypt_data("hunter2", SALT, IV, plaintext)

        archive = build_zip(
            {f"{steam_id}.maFile": ciphertext.encode()},
            manifest={
                "encrypted": True,
                "entries": [
                    {
                        "filename": f"{steam_id}.maFile",
                        "steamid": steam_id,
                        "encryption_salt": SALT,
                        "encryption_iv": IV,
                    }
                ],
            },
        )

        report = await import_archive(store, archive, passkey="hunter2")

        assert len(report.imported) == 1
        assert store.get(steam_id).account_name == "encrypted-user"

    async def test_wrong_passkey_is_reported_not_swallowed(self, store):
        steam_id = 76561198000000009
        ciphertext = file_encryptor.encrypt_data(
            "hunter2", SALT, IV, json.dumps(make_mafile(steam_id, "x"))
        )
        archive = build_zip(
            {f"{steam_id}.maFile": ciphertext.encode()},
            manifest={
                "entries": [
                    {
                        "filename": f"{steam_id}.maFile",
                        "steamid": steam_id,
                        "encryption_salt": SALT,
                        "encryption_iv": IV,
                    }
                ]
            },
        )

        report = await import_archive(store, archive, passkey="wrong")

        assert not report.imported
        assert report.failed[0].error == "wrong passkey"

    async def test_encrypted_without_a_passkey_says_so(self, store):
        steam_id = 76561198000000009
        ciphertext = file_encryptor.encrypt_data(
            "hunter2", SALT, IV, json.dumps(make_mafile(steam_id, "x"))
        )
        archive = build_zip(
            {f"{steam_id}.maFile": ciphertext.encode()},
            manifest={
                "entries": [
                    {
                        "filename": f"{steam_id}.maFile",
                        "steamid": steam_id,
                        "encryption_salt": SALT,
                        "encryption_iv": IV,
                    }
                ]
            },
        )

        report = await import_archive(store, archive)

        assert report.needed_passkey is True

    async def test_mixed_plain_and_encrypted(self, store):
        plain_id, enc_id = 76561198000000001, 76561198000000002
        ciphertext = file_encryptor.encrypt_data(
            "hunter2", SALT, IV, json.dumps(make_mafile(enc_id, "enc"))
        )

        archive = build_zip(
            {
                f"{plain_id}.maFile": json.dumps(
                    make_mafile(plain_id, "plain")
                ).encode(),
                f"{enc_id}.maFile": ciphertext.encode(),
            },
            manifest={
                "entries": [
                    {
                        "filename": f"{enc_id}.maFile",
                        "steamid": enc_id,
                        "encryption_salt": SALT,
                        "encryption_iv": IV,
                    }
                ]
            },
        )

        report = await import_archive(store, archive, passkey="hunter2")

        assert len(report.imported) == 2
        assert len(store) == 2

    async def test_a_broken_manifest_does_not_abort_the_import(self, store):
        archive = build_zip(
            {
                "76561198000000001.maFile": json.dumps(
                    make_mafile(76561198000000001, "plain")
                ).encode(),
                "manifest.json": b"{ not json",
            }
        )

        report = await import_archive(store, archive)

        assert len(report.imported) == 1

    async def test_rejects_a_non_zip(self, store):
        with pytest.raises(ValueError, match="readable .zip"):
            await import_archive(store, b"definitely not a zip")

    async def test_rejects_an_archive_with_no_mafiles(self, store):
        with pytest.raises(ValueError, match="No .maFile"):
            await import_archive(store, build_zip({"readme.txt": b"hi"}))

    async def test_rejects_too_many_entries(self, store):
        members = {
            f"f{i}.maFile": b"{}" for i in range(MAX_ARCHIVE_ENTRIES + 1)
        }

        with pytest.raises(ValueError, match="limit is"):
            await import_archive(store, build_zip(members))

    async def test_rejects_a_decompression_bomb(self, store):
        # Compresses to a few KB, expands past the ceiling.
        archive = build_zip({"huge.maFile": b"\x00" * (65 * 1024 * 1024)})

        with pytest.raises(ValueError, match="too much data"):
            await import_archive(store, archive)

    async def test_imported_accounts_are_encrypted_at_rest(self, tmp_path):
        """Import writes through the store, so SDA_PASSKEY still applies."""
        store = AccountStore(tmp_path, passkey="storage-key")
        await store.load()

        await import_archive(store, plain_zip(2))

        for path in tmp_path.glob("*.maFile"):
            assert "shared_secret" not in path.read_text("utf-8")
