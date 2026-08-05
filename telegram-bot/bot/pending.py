"""Short-lived QR login requests awaiting a decision.

Kept in memory on purpose: a login challenge is useless once Steam expires it,
so there is nothing worth persisting, and not writing it means a scanned code
never lands on disk.
"""

from __future__ import annotations

import secrets
import time
from dataclasses import dataclass, field

from steamguard import QrChallenge


@dataclass
class PendingQr:
    token: str
    user_id: int
    challenge: QrChallenge
    created_at: float
    steam_id: int | None = None
    extra: dict = field(default_factory=dict)


class PendingQrRequests:
    """A TTL-bounded map of decoded QR codes keyed by a short opaque token.

    The token, not the client_id, travels in callback data — callback payloads
    are capped at 64 bytes and this keeps Steam identifiers out of them.
    """

    def __init__(self, ttl_seconds: int = 180) -> None:
        self._ttl = ttl_seconds
        self._items: dict[str, PendingQr] = {}

    def add(
        self, user_id: int, challenge: QrChallenge, steam_id: int | None = None
    ) -> PendingQr:
        self._evict_expired()

        token = secrets.token_urlsafe(8)
        pending = PendingQr(
            token=token,
            user_id=user_id,
            challenge=challenge,
            created_at=time.monotonic(),
            steam_id=steam_id,
        )
        self._items[token] = pending
        return pending

    def get(self, token: str, user_id: int) -> PendingQr | None:
        """Fetch a request, but only for the user who created it.

        The ownership check is what stops one guest from acting on another's
        pending login by guessing or replaying a token.
        """
        self._evict_expired()

        pending = self._items.get(token)
        if pending is None or pending.user_id != user_id:
            return None
        return pending

    def pop(self, token: str, user_id: int) -> PendingQr | None:
        pending = self.get(token, user_id)
        if pending is not None:
            self._items.pop(token, None)
        return pending

    def _evict_expired(self) -> None:
        cutoff = time.monotonic() - self._ttl
        for token in [
            t for t, item in self._items.items() if item.created_at < cutoff
        ]:
            self._items.pop(token, None)
