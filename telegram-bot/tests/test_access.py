"""The permission model — the part that decides what a guest can reach."""

from __future__ import annotations

import json

import pytest

from bot.access import ShareRegistry
from bot.pending import PendingQrRequests
from steamguard import QrChallenge

ACCOUNT_A = 76561198000000001
ACCOUNT_B = 76561198000000002
GUEST = 111
OTHER_GUEST = 222


@pytest.fixture
def registry(tmp_path) -> ShareRegistry:
    reg = ShareRegistry(tmp_path)
    reg.load()
    return reg


class TestShareRegistry:
    def test_starts_empty(self, registry):
        assert registry.all_shares() == []
        assert not registry.has_any(GUEST)

    def test_grant_then_query(self, registry):
        assert registry.grant(GUEST, ACCOUNT_A, "Friend") is True

        assert registry.is_allowed(GUEST, ACCOUNT_A)
        assert registry.steam_ids_for(GUEST) == [ACCOUNT_A]
        assert registry.has_any(GUEST)

    def test_grant_is_idempotent(self, registry):
        assert registry.grant(GUEST, ACCOUNT_A, "Friend") is True
        assert registry.grant(GUEST, ACCOUNT_A, "Friend") is False
        assert len(registry.all_shares()) == 1

    def test_a_share_does_not_leak_to_other_accounts(self, registry):
        registry.grant(GUEST, ACCOUNT_A, "Friend")

        assert not registry.is_allowed(GUEST, ACCOUNT_B)
        assert registry.steam_ids_for(GUEST) == [ACCOUNT_A]

    def test_a_share_does_not_leak_to_other_users(self, registry):
        registry.grant(GUEST, ACCOUNT_A, "Friend")

        assert not registry.is_allowed(OTHER_GUEST, ACCOUNT_A)
        assert registry.steam_ids_for(OTHER_GUEST) == []

    def test_revoke(self, registry):
        registry.grant(GUEST, ACCOUNT_A, "Friend")

        assert registry.revoke(GUEST, ACCOUNT_A) is True
        assert not registry.is_allowed(GUEST, ACCOUNT_A)
        assert registry.revoke(GUEST, ACCOUNT_A) is False

    def test_revoking_an_account_drops_every_share_for_it(self, registry):
        registry.grant(GUEST, ACCOUNT_A, "One")
        registry.grant(OTHER_GUEST, ACCOUNT_A, "Two")
        registry.grant(GUEST, ACCOUNT_B, "One")

        assert registry.revoke_account(ACCOUNT_A) == 2
        assert registry.steam_ids_for(GUEST) == [ACCOUNT_B]
        assert registry.steam_ids_for(OTHER_GUEST) == []

    def test_survives_a_reload(self, registry, tmp_path):
        registry.grant(GUEST, ACCOUNT_A, "Friend")

        reloaded = ShareRegistry(tmp_path)
        reloaded.load()
        assert reloaded.is_allowed(GUEST, ACCOUNT_A)

    def test_corrupt_file_does_not_lock_the_admin_out(self, tmp_path):
        (tmp_path / "shares.json").write_text("{ not json", "utf-8")

        registry = ShareRegistry(tmp_path)
        registry.load()  # must not raise

        assert registry.all_shares() == []

    def test_written_file_is_readable_json(self, registry, tmp_path):
        registry.grant(GUEST, ACCOUNT_A, "Friend")

        payload = json.loads((tmp_path / "shares.json").read_text("utf-8"))
        assert payload["shares"][0]["user_id"] == GUEST
        assert payload["shares"][0]["steam_id"] == ACCOUNT_A


class TestPendingQrRequests:
    def _challenge(self) -> QrChallenge:
        return QrChallenge(version=1, client_id="2207813151333862682")

    def test_round_trip(self):
        pending = PendingQrRequests()
        item = pending.add(GUEST, self._challenge())

        assert pending.get(item.token, GUEST) is item

    def test_another_user_cannot_read_someone_elses_request(self):
        """The check that stops one guest acting on another's pending login."""
        pending = PendingQrRequests()
        item = pending.add(GUEST, self._challenge())

        assert pending.get(item.token, OTHER_GUEST) is None
        assert pending.pop(item.token, OTHER_GUEST) is None

    def test_pop_is_single_use(self):
        pending = PendingQrRequests()
        item = pending.add(GUEST, self._challenge())

        assert pending.pop(item.token, GUEST) is item
        assert pending.pop(item.token, GUEST) is None

    def test_expired_requests_are_evicted(self):
        pending = PendingQrRequests(ttl_seconds=0)
        item = pending.add(GUEST, self._challenge())

        assert pending.get(item.token, GUEST) is None

    def test_unknown_token_is_rejected(self):
        pending = PendingQrRequests()
        assert pending.get("nonexistent", GUEST) is None

    def test_tokens_are_unique(self):
        pending = PendingQrRequests()
        tokens = {pending.add(GUEST, self._challenge()).token for _ in range(50)}
        assert len(tokens) == 50
