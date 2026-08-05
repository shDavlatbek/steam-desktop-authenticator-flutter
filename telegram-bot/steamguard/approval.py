"""Approving QR logins started on other devices.

This is the role the official Steam mobile app plays when it scans a login QR.
Both calls authenticate with an access token on the query string, and that
token must have been issued for platform type 3 (MobileApp) — a web-only token
comes back as EResult 15.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from urllib.parse import quote

from . import mobile_signature
from .constants import ApiEndpoints
from .models import SteamGuardAccount
from .qr_challenge import QrChallenge
from .web import SteamWeb

log = logging.getLogger(__name__)


class LoginApprovalError(Exception):
    """Steam rejected an approval request."""


@dataclass
class AuthSessionInfo:
    """Details of a pending login, shown before anyone approves it."""

    ip: str | None = None
    city: str | None = None
    state: str | None = None
    country: str | None = None
    platform_type: int | None = None
    device_name: str | None = None
    version: int = 1
    login_history: int | None = None
    location_mismatch: bool = False
    high_usage_login: bool = False

    @classmethod
    def from_json(cls, data: dict) -> "AuthSessionInfo":
        return cls(
            ip=data.get("ip"),
            city=data.get("city"),
            state=data.get("state"),
            country=data.get("country"),
            platform_type=data.get("platform_type"),
            device_name=data.get("device_friendly_name"),
            version=int(data.get("version") or 1),
            login_history=data.get("login_history"),
            location_mismatch=bool(data.get("requestor_location_mismatch")),
            high_usage_login=bool(data.get("high_usage_login")),
        )

    @property
    def location(self) -> str:
        parts = [p for p in (self.city, self.state, self.country) if p]
        return ", ".join(parts) if parts else "Unknown location"

    @property
    def platform_name(self) -> str:
        return {
            1: "Steam Client",
            2: "Web Browser",
            3: "Mobile App",
        }.get(self.platform_type or 0, "Unknown")

    @property
    def is_suspicious(self) -> bool:
        """Whether Steam flagged anything unusual about the request."""
        return self.location_mismatch or self.login_history == 1


class LoginApproval:
    def __init__(self, web: SteamWeb) -> None:
        self._web = web

    async def get_session_info(
        self, access_token: str, challenge: QrChallenge
    ) -> AuthSessionInfo:
        response = await self._web.post_for_response(
            _with_token(ApiEndpoints.AUTH_GET_SESSION_INFO, access_token),
            data={"client_id": challenge.client_id},
        )
        if not response.ok:
            raise LoginApprovalError(response.failure_reason)

        payload = json.loads(response.body).get("response") or {}
        if not payload:
            raise LoginApprovalError(
                "That login request no longer exists — it may have expired."
            )

        return AuthSessionInfo.from_json(payload)

    async def respond(
        self,
        account: SteamGuardAccount,
        challenge: QrChallenge,
        approve: bool,
    ) -> None:
        """Approve or deny the pending login on ``account``'s behalf."""
        if not account.shared_secret:
            raise LoginApprovalError(
                f"{account.display_name} has no shared secret, so it cannot "
                "approve logins."
            )
        if not account.session or not account.session.access_token:
            raise LoginApprovalError(
                f"{account.display_name} has no active session."
            )

        signature = mobile_signature.generate_base64(
            shared_secret=account.shared_secret,
            version=challenge.version,
            client_id=challenge.client_id,
            steam_id=account.steam_id,
        )

        log.info(
            "%s login %s for %s",
            "Approving" if approve else "Denying",
            challenge.client_id,
            account.display_name,
        )

        response = await self._web.post_for_response(
            _with_token(
                ApiEndpoints.AUTH_UPDATE_WITH_MOBILE_CONFIRMATION,
                account.session.access_token,
            ),
            data={
                "version": str(challenge.version),
                "client_id": challenge.client_id,
                "steamid": str(account.steam_id),
                "signature": signature,
                "confirm": "1" if approve else "0",
                "persistence": "1",
            },
        )

        if not response.ok:
            raise LoginApprovalError(response.failure_reason)


def _with_token(url: str, access_token: str) -> str:
    return f"{url}?access_token={quote(access_token, safe='')}"
