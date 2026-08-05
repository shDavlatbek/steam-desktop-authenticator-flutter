"""Expired-session detection, and what a guest is allowed to see because of it.

This is the case that showed up in production: a guest picked an account, tapped
Approve, and only then discovered the stored login was dead.
"""

from __future__ import annotations

import base64
import json
import time

import pytest

from bot.access import ShareRegistry
from bot.handlers.admin import _is_expired, _session_status
from bot.handlers.guest import _approvable_accounts, _expired_accounts
from steamguard import SessionData, SteamGuardAccount

GUEST = 111
LIVE_ID = 76561198000000001
DEAD_ID = 76561198000000002
SECRETLESS_ID = 76561198000000003


def jwt(exp_offset: int, sub: int = LIVE_ID) -> str:
    """A JWT shaped like Steam's, expiring ``exp_offset`` seconds from now."""
    claims = {"sub": str(sub), "exp": int(time.time()) + exp_offset}
    payload = (
        base64.urlsafe_b64encode(json.dumps(claims).encode())
        .decode()
        .rstrip("=")
    )
    return f"header.{payload}.signature"


def account(
    steam_id: int,
    *,
    refresh_offset: int = 3600,
    access_offset: int = 3600,
    shared_secret: str | None = "AQIDBAUGBwgJCgsMDQ4PEBESExQ=",
) -> SteamGuardAccount:
    return SteamGuardAccount(
        account_name=f"acct{steam_id}",
        shared_secret=shared_secret,
        session=SessionData(
            steam_id=steam_id,
            access_token=jwt(access_offset, steam_id),
            refresh_token=jwt(refresh_offset, steam_id),
            session_id="0" * 32,
        ),
    )


class FakeStore:
    def __init__(self, accounts: list[SteamGuardAccount]) -> None:
        self._by_id = {a.steam_id: a for a in accounts}

    def get(self, steam_id: int):
        return self._by_id.get(steam_id)

    def all_accounts(self):
        return list(self._by_id.values())


class FakeServices:
    def __init__(self, accounts, shares) -> None:
        self.store = FakeStore(accounts)
        self.shares = shares


class TestSessionExpiry:
    def test_a_live_refresh_token_is_not_expired(self):
        assert not account(LIVE_ID).session.is_refresh_token_expired()

    def test_a_past_exp_is_expired(self):
        assert account(LIVE_ID, refresh_offset=-60).session.is_refresh_token_expired()

    def test_a_missing_token_counts_as_expired(self):
        session = SessionData(steam_id=LIVE_ID)
        assert session.is_refresh_token_expired()
        assert session.is_access_token_expired()

    def test_an_expired_access_token_alone_is_recoverable(self):
        """Routine — it refreshes itself; only the refresh token is fatal."""
        stale = account(LIVE_ID, access_offset=-60)

        assert stale.session.is_access_token_expired()
        assert not stale.session.is_refresh_token_expired()
        assert not _is_expired(stale)

    def test_is_expired_covers_a_missing_session(self):
        assert _is_expired(SteamGuardAccount(account_name="x"))

    def test_status_text_distinguishes_the_three_cases(self):
        assert _session_status(account(LIVE_ID)) == "ok"
        assert "refresh" in _session_status(account(LIVE_ID, access_offset=-60))
        assert "expired" in _session_status(account(LIVE_ID, refresh_offset=-60))
        assert _session_status(SteamGuardAccount()) == "none stored"


class TestGuestVisibility:
    @pytest.fixture
    def services(self, tmp_path):
        shares = ShareRegistry(tmp_path)
        shares.load()
        for steam_id in (LIVE_ID, DEAD_ID, SECRETLESS_ID):
            shares.grant(GUEST, steam_id, "Friend")

        return FakeServices(
            [
                account(LIVE_ID),
                account(DEAD_ID, refresh_offset=-60),
                account(SECRETLESS_ID, shared_secret=None),
            ],
            shares,
        )

    def test_only_usable_accounts_are_offered(self, services):
        usable = _approvable_accounts(GUEST, services, is_admin=False)

        assert [a.steam_id for a in usable] == [LIVE_ID]

    def test_expired_accounts_are_reported_separately(self, services):
        """So the guest gets a real explanation and the owner gets told."""
        stale = _expired_accounts(GUEST, services, is_admin=False)

        assert [a.steam_id for a in stale] == [DEAD_ID]

    def test_an_account_without_a_secret_is_neither(self, services):
        """It can never approve, so it is not a re-login problem."""
        usable = _approvable_accounts(GUEST, services, is_admin=False)
        stale = _expired_accounts(GUEST, services, is_admin=False)

        assert SECRETLESS_ID not in {a.steam_id for a in usable + stale}

    def test_a_guest_without_shares_sees_nothing(self, services):
        assert _approvable_accounts(999, services, is_admin=False) == []
        assert _expired_accounts(999, services, is_admin=False) == []

    def test_admin_sees_every_account_regardless_of_shares(self, services):
        usable = _approvable_accounts(0, services, is_admin=True)
        stale = _expired_accounts(0, services, is_admin=True)

        assert [a.steam_id for a in usable] == [LIVE_ID]
        assert [a.steam_id for a in stale] == [DEAD_ID]

    def test_revoking_hides_the_account_immediately(self, services):
        services.shares.revoke(GUEST, LIVE_ID)

        assert _approvable_accounts(GUEST, services, is_admin=False) == []
