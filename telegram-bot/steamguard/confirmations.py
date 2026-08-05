"""Trade and market confirmations via the mobileconf endpoints.

Request shapes mirror the desktop app exactly, including the quirk that
multiajaxop takes everything in a raw form-encoded body with repeated
cid[]/ck[] keys rather than a query string.
"""

from __future__ import annotations

import json
import logging

from . import confirmation_hash
from .auth import NeedsReauthError, SteamAuth
from .constants import ApiEndpoints
from .models import Confirmation, SteamGuardAccount
from .time_sync import SteamTime
from .web import SteamWeb

log = logging.getLogger(__name__)


class ConfirmationError(Exception):
    """Steam refused a confirmation request."""


class Confirmations:
    def __init__(self, web: SteamWeb, auth: SteamAuth, clock: SteamTime) -> None:
        self._web = web
        self._auth = auth
        self._clock = clock

    async def fetch(self, account: SteamGuardAccount) -> list[Confirmation]:
        """List pending confirmations."""
        await self._prepare(account)

        query = await self._query_params(account, "conf")
        url = f"{ApiEndpoints.CONFIRMATION_GET_LIST}?{query}"

        body = await self._web.get(url, cookies=account.session.cookies())
        try:
            payload = json.loads(body)
        except ValueError as exc:
            raise ConfirmationError(
                "Steam returned something unreadable — the session may be bad."
            ) from exc

        if payload.get("needauth"):
            raise NeedsReauthError("Session expired; sign in again.")
        if not payload.get("success"):
            raise ConfirmationError(
                payload.get("message") or "Failed to fetch confirmations."
            )

        return [
            Confirmation.from_json(item)
            for item in payload.get("conf") or []
        ]

    async def respond(
        self,
        account: SteamGuardAccount,
        confirmation: Confirmation,
        accept: bool,
    ) -> None:
        """Accept or deny a single confirmation."""
        await self._prepare(account)

        op = "allow" if accept else "cancel"
        query = await self._query_params(account, "accept" if accept else "reject")
        url = (
            f"{ApiEndpoints.CONFIRMATION_AJAX_OP}?op={op}&{query}"
            f"&cid={confirmation.id}&ck={confirmation.nonce}"
        )

        body = await self._web.get(url, cookies=account.session.cookies())
        if not _succeeded(body):
            raise ConfirmationError("Steam rejected the confirmation.")

    async def respond_all(
        self,
        account: SteamGuardAccount,
        confirmations: list[Confirmation],
        accept: bool,
    ) -> None:
        """Accept or deny several confirmations in one request."""
        if not confirmations:
            return

        await self._prepare(account)

        op = "allow" if accept else "cancel"
        query = await self._query_params(account, "accept" if accept else "reject")

        parts = [f"op={op}", query]
        for confirmation in confirmations:
            parts.append(f"cid[]={confirmation.id}")
            parts.append(f"ck[]={confirmation.nonce}")

        body = await self._web.post_raw(
            ApiEndpoints.CONFIRMATION_MULTI_AJAX_OP,
            body="&".join(parts),
            cookies=account.session.cookies(),
        )
        if not _succeeded(body):
            raise ConfirmationError("Steam rejected the bulk confirmation.")

    async def _prepare(self, account: SteamGuardAccount) -> None:
        if not account.identity_secret:
            raise ConfirmationError(
                f"{account.display_name} has no identity secret, so its "
                "confirmations cannot be signed."
            )
        if not account.device_id:
            raise ConfirmationError(
                f"{account.display_name} has no device ID."
            )
        await self._auth.ensure_valid_session(account.session)

    async def _query_params(self, account: SteamGuardAccount, tag: str) -> str:
        timestamp = await self._clock.current()
        digest = confirmation_hash.generate_for_time(
            account.identity_secret, timestamp, tag
        )
        if digest is None:
            raise ConfirmationError("Could not sign the confirmation request.")

        return "&".join(
            f"{key}={value}"
            for key, value in {
                "p": account.device_id,
                "a": str(account.steam_id),
                "k": digest,
                "t": str(timestamp),
                "m": "react",
                "tag": tag,
            }.items()
        )


def _succeeded(body: str) -> bool:
    try:
        return json.loads(body).get("success") is True
    except ValueError:
        return False
