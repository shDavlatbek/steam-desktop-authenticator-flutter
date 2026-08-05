"""Who may use which account, and for what.

The model is deliberately narrow. Exactly one admin — the ADMIN_ID from the
environment — can do everything. Everyone else is a guest, and a guest can do
exactly one thing: approve a QR login for an account explicitly shared with
them. Guests never see codes, confirmations, secrets, or accounts they were not
granted.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict, dataclass
from pathlib import Path

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Share:
    """One guest's permission to approve logins for one Steam account."""

    user_id: int
    steam_id: int
    display_name: str
    granted_at: int

    @classmethod
    def from_json(cls, data: dict) -> "Share":
        return cls(
            user_id=int(data["user_id"]),
            steam_id=int(data["steam_id"]),
            display_name=data.get("display_name") or str(data["user_id"]),
            granted_at=int(data.get("granted_at") or 0),
        )


class ShareRegistry:
    """Persistent guest→account grants, stored in shares.json."""

    def __init__(self, data_dir: Path) -> None:
        self._path = Path(data_dir) / "shares.json"
        self._shares: list[Share] = []

    def load(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)

        if not self._path.exists():
            self._shares = []
            return

        try:
            raw = json.loads(self._path.read_text("utf-8"))
            self._shares = [Share.from_json(item) for item in raw.get("shares", [])]
        except (OSError, ValueError, KeyError) as exc:
            # Failing closed would lock the admin out of their own bot, so log
            # loudly and continue with no grants rather than refusing to start.
            log.error("shares.json is unreadable (%s); starting with no shares", exc)
            self._shares = []

        log.info("Loaded %d share(s)", len(self._shares))

    def _save(self) -> None:
        tmp = self._path.with_suffix(".json.tmp")
        tmp.write_text(
            json.dumps({"shares": [asdict(s) for s in self._shares]}, indent=2),
            "utf-8",
        )
        tmp.replace(self._path)

    # ── Queries ──────────────────────────────────────────────────────────

    def steam_ids_for(self, user_id: int) -> list[int]:
        """Accounts this guest may approve logins for."""
        return [s.steam_id for s in self._shares if s.user_id == user_id]

    def shares_for_account(self, steam_id: int) -> list[Share]:
        return [s for s in self._shares if s.steam_id == steam_id]

    def all_shares(self) -> list[Share]:
        return list(self._shares)

    def has_any(self, user_id: int) -> bool:
        return any(s.user_id == user_id for s in self._shares)

    def is_allowed(self, user_id: int, steam_id: int) -> bool:
        return any(
            s.user_id == user_id and s.steam_id == steam_id for s in self._shares
        )

    # ── Mutations ────────────────────────────────────────────────────────

    def grant(self, user_id: int, steam_id: int, display_name: str) -> bool:
        """Grant access. Returns False if it already existed."""
        if self.is_allowed(user_id, steam_id):
            return False

        self._shares.append(
            Share(
                user_id=user_id,
                steam_id=steam_id,
                display_name=display_name,
                granted_at=int(time.time()),
            )
        )
        self._save()
        log.info("Granted %s access to %s", user_id, steam_id)
        return True

    def revoke(self, user_id: int, steam_id: int) -> bool:
        before = len(self._shares)
        self._shares = [
            s
            for s in self._shares
            if not (s.user_id == user_id and s.steam_id == steam_id)
        ]
        if len(self._shares) == before:
            return False

        self._save()
        log.info("Revoked %s access to %s", user_id, steam_id)
        return True

    def revoke_account(self, steam_id: int) -> int:
        """Drop every share for an account. Used when it is removed."""
        before = len(self._shares)
        self._shares = [s for s in self._shares if s.steam_id != steam_id]
        removed = before - len(self._shares)
        if removed:
            self._save()
        return removed
