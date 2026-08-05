"""Storage, and its compatibility with the desktop app's on-disk format."""

from __future__ import annotations

import json

import pytest

from steamguard import AccountStore, SessionData, SteamGuardAccount, WrongPasskeyError

STEAM_ID = 76561198123456789

# The exact key casing the C# original and the Flutter app both write. If this
# drifts, .maFiles stop moving between the app and the bot.
APP_MAFILE = {
    "shared_secret": "AQIDBAUGBwgJCgsMDQ4PEBESExQ=",
    "serial_number": "1234567890",
    "revocation_code": "R12345",
    "uri": "otpauth://totp/Steam:tester?secret=ABC",
    "server_time": 1700000000,
    "account_name": "tester",
    "token_gid": "abcdef",
    "identity_secret": "FBUWFxgZGhscHR4fICEiIyQlJic=",
    "secret_1": "KCkqKywtLi8wMTIzNDU2Nzg5Ojs8",
    "status": 1,
    "device_id": "android:11111111-2222-3333-4444-555555555555",
    "phone_number_hint": "42",
    "confirm_type": 2,
    "fully_enrolled": True,
    "Session": {
        "SteamID": STEAM_ID,
        "AccessToken": "eyJhbGciOiJIUzI1NiJ9.e30.sig",
        "RefreshToken": "eyJhbGciOiJIUzI1NiJ9.e30.sig",
        "SessionID": "0123456789abcdef0123456789abcdef",
    },
}


def _account() -> SteamGuardAccount:
    return SteamGuardAccount.from_json(APP_MAFILE)


class TestModelCompatibility:
    def test_round_trips_every_key_the_app_writes(self):
        assert _account().to_json() == APP_MAFILE

    def test_session_is_pascal_case(self):
        """Session keys differ in casing from the rest of the file."""
        payload = _account().to_json()
        assert set(payload["Session"]) == {
            "SteamID",
            "AccessToken",
            "RefreshToken",
            "SessionID",
        }

    def test_reads_steam_id_from_a_jwt_sub_claim(self):
        # A QR login only reveals the SteamID through the token.
        import base64

        claims = base64.urlsafe_b64encode(
            json.dumps({"sub": str(STEAM_ID), "exp": 9999999999}).encode()
        ).decode().rstrip("=")
        token = f"header.{claims}.signature"

        assert SessionData.steam_id_from_token(token) == STEAM_ID

    @pytest.mark.parametrize("token", ["", "not-a-jwt", "a.b", "a.!!!.c"])
    def test_malformed_tokens_yield_none(self, token):
        assert SessionData.steam_id_from_token(token) is None

    def test_capability_flags(self):
        account = _account()
        assert account.can_generate_codes()
        assert account.can_approve_logins()

        account.shared_secret = None
        assert not account.can_generate_codes()
        assert not account.can_approve_logins()


class TestAccountStore:
    async def test_saves_and_reloads_plaintext(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()
        await store.save_account(_account())

        reloaded = AccountStore(tmp_path)
        await reloaded.load()

        assert len(reloaded) == 1
        assert reloaded.get(STEAM_ID).account_name == "tester"

    async def test_plaintext_file_is_readable_by_the_app(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()
        await store.save_account(_account())

        written = json.loads((tmp_path / f"{STEAM_ID}.maFile").read_text("utf-8"))
        assert written == APP_MAFILE

        manifest = json.loads((tmp_path / "manifest.json").read_text("utf-8"))
        assert manifest["encrypted"] is False
        assert manifest["entries"][0]["steamid"] == STEAM_ID
        assert manifest["entries"][0]["filename"] == f"{STEAM_ID}.maFile"

    async def test_encrypts_at_rest_when_a_passkey_is_set(self, tmp_path):
        store = AccountStore(tmp_path, passkey="hunter2")
        await store.load()
        await store.save_account(_account())

        raw = (tmp_path / f"{STEAM_ID}.maFile").read_text("utf-8")
        assert "shared_secret" not in raw  # the whole point

        manifest = json.loads((tmp_path / "manifest.json").read_text("utf-8"))
        assert manifest["encrypted"] is True
        assert manifest["entries"][0]["encryption_salt"]
        assert manifest["entries"][0]["encryption_iv"]

    async def test_encrypted_accounts_reload_with_the_right_key(self, tmp_path):
        store = AccountStore(tmp_path, passkey="hunter2")
        await store.load()
        await store.save_account(_account())

        reloaded = AccountStore(tmp_path, passkey="hunter2")
        await reloaded.load()
        assert reloaded.get(STEAM_ID).shared_secret == APP_MAFILE["shared_secret"]

    async def test_wrong_passkey_is_refused_rather_than_silently_empty(
        self, tmp_path
    ):
        store = AccountStore(tmp_path, passkey="hunter2")
        await store.load()
        await store.save_account(_account())

        with pytest.raises(WrongPasskeyError):
            await AccountStore(tmp_path, passkey="wrong").load()

    async def test_missing_passkey_for_encrypted_store_is_refused(self, tmp_path):
        store = AccountStore(tmp_path, passkey="hunter2")
        await store.load()
        await store.save_account(_account())

        with pytest.raises(WrongPasskeyError):
            await AccountStore(tmp_path).load()

    async def test_remove_deletes_the_file_and_entry(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()
        await store.save_account(_account())

        assert await store.remove_account(STEAM_ID) is True
        assert not (tmp_path / f"{STEAM_ID}.maFile").exists()
        assert len(store) == 0
        assert await store.remove_account(STEAM_ID) is False

    async def test_entries_without_a_file_are_pruned(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()
        await store.save_account(_account())

        (tmp_path / f"{STEAM_ID}.maFile").unlink()

        reloaded = AccountStore(tmp_path)
        await reloaded.load()
        assert len(reloaded) == 0

    async def test_saving_twice_replaces_rather_than_duplicates(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()

        await store.save_account(_account())
        updated = _account()
        updated.account_name = "renamed"
        await store.save_account(updated)

        manifest = json.loads((tmp_path / "manifest.json").read_text("utf-8"))
        assert len(manifest["entries"]) == 1
        assert store.get(STEAM_ID).account_name == "renamed"

    async def test_import_accepts_an_app_exported_mafile(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()

        account = await store.import_mafile(json.dumps(APP_MAFILE).encode())

        assert account.steam_id == STEAM_ID
        assert store.get(STEAM_ID) is not None

    @pytest.mark.parametrize(
        "payload",
        [
            b"not json at all",
            json.dumps({"account_name": "x"}).encode(),  # no shared_secret
            json.dumps({"shared_secret": "abc"}).encode(),  # no SteamID
        ],
    )
    async def test_import_rejects_bad_input(self, tmp_path, payload):
        store = AccountStore(tmp_path)
        await store.load()

        with pytest.raises(ValueError):
            await store.import_mafile(payload)

    async def test_export_returns_the_app_format(self, tmp_path):
        store = AccountStore(tmp_path)
        await store.load()
        await store.save_account(_account())

        exported = json.loads(store.export_mafile(STEAM_ID).decode())
        assert exported == APP_MAFILE
        assert store.export_mafile(999) is None
