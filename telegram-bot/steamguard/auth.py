"""Steam login: RSA credential auth, QR sessions, and token refresh."""

from __future__ import annotations

import base64
import json
import logging
from dataclasses import dataclass, field

from cryptography.hazmat.primitives.asymmetric import padding, rsa

from .constants import PLATFORM_TYPE_MOBILE_APP, ApiEndpoints
from .models import SessionData
from .web import SteamWeb

log = logging.getLogger(__name__)


class SteamAuthError(Exception):
    """Steam refused a login step."""


class NeedsReauthError(Exception):
    """The stored session is dead; the account must sign in again."""


@dataclass
class AuthSession:
    """An in-progress login, credential or QR."""

    client_id: str
    request_id: str
    steam_id: str | None = None
    interval: int = 5
    allowed_confirmations: list[int] = field(default_factory=list)
    challenge_url: str | None = None
    version: int = 1


class SteamAuth:
    def __init__(self, web: SteamWeb) -> None:
        self._web = web

    # ── Credential login ─────────────────────────────────────────────────

    async def _rsa_key(self, account_name: str) -> dict[str, str]:
        body = await self._web.get(
            f"{ApiEndpoints.AUTH_GET_RSA_KEY}?account_name={account_name}"
        )
        payload = json.loads(body).get("response") or {}
        if "publickey_mod" not in payload:
            raise SteamAuthError("Steam did not return an RSA key for that user.")
        return payload

    @staticmethod
    def _encrypt_password(password: str, modulus_hex: str, exponent_hex: str) -> str:
        public_key = rsa.RSAPublicNumbers(
            e=int(exponent_hex, 16), n=int(modulus_hex, 16)
        ).public_key()
        ciphertext = public_key.encrypt(
            password.encode("utf-8"), padding.PKCS1v15()
        )
        return base64.b64encode(ciphertext).decode("ascii")

    async def begin_with_credentials(
        self, account_name: str, password: str
    ) -> AuthSession:
        """Start a password login. 2FA, if required, is submitted separately."""
        key = await self._rsa_key(account_name)

        body = await self._web.post(
            ApiEndpoints.AUTH_BEGIN_VIA_CREDENTIALS,
            data={
                "account_name": account_name,
                "encrypted_password": self._encrypt_password(
                    password, key["publickey_mod"], key["publickey_exp"]
                ),
                "encryption_timestamp": str(key["timestamp"]),
                "persistence": "1",
                "platform_type": str(PLATFORM_TYPE_MOBILE_APP),
            },
        )

        payload = json.loads(body).get("response") or {}
        if not payload.get("client_id"):
            raise SteamAuthError(
                "Steam rejected those credentials, or is rate limiting logins."
            )

        return AuthSession(
            client_id=str(payload["client_id"]),
            request_id=str(payload.get("request_id") or ""),
            steam_id=str(payload.get("steamid") or "") or None,
            interval=int(float(payload.get("interval") or 5)),
            allowed_confirmations=[
                int(c.get("confirmation_type", 0))
                for c in payload.get("allowed_confirmations") or []
            ],
        )

    async def submit_guard_code(
        self, session: AuthSession, code: str, code_type: int
    ) -> None:
        """Submit an email (2) or authenticator (3) code."""
        await self._web.post(
            ApiEndpoints.AUTH_UPDATE_WITH_GUARD_CODE,
            data={
                "client_id": session.client_id,
                "steamid": session.steam_id or "",
                "code": code,
                "code_type": str(code_type),
            },
        )

    # ── QR login ─────────────────────────────────────────────────────────

    async def begin_with_qr(
        self, device_name: str = "Steam Desktop Authenticator"
    ) -> AuthSession:
        """Start a QR session, returning a challenge URL to render."""
        body = await self._web.post(
            ApiEndpoints.AUTH_BEGIN_VIA_QR,
            data={
                "device_friendly_name": device_name,
                "platform_type": str(PLATFORM_TYPE_MOBILE_APP),
            },
        )

        payload = json.loads(body).get("response") or {}
        if not payload.get("challenge_url"):
            raise SteamAuthError("Steam did not return a QR challenge.")

        return AuthSession(
            client_id=str(payload["client_id"]),
            request_id=str(payload.get("request_id") or ""),
            interval=int(float(payload.get("interval") or 5)),
            challenge_url=payload["challenge_url"],
            version=int(payload.get("version") or 1),
        )

    # ── Polling ──────────────────────────────────────────────────────────

    async def poll(self, session: AuthSession) -> dict[str, object]:
        """Poll once. Mutates ``session`` when Steam rotates its identifiers."""
        body = await self._web.post(
            ApiEndpoints.AUTH_POLL_SESSION,
            data={
                "client_id": session.client_id,
                "request_id": session.request_id,
            },
        )
        payload = json.loads(body).get("response") or {}

        new_client_id = payload.get("new_client_id")
        if new_client_id and str(new_client_id) != "0":
            session.client_id = str(new_client_id)
        if payload.get("new_challenge_url"):
            session.challenge_url = payload["new_challenge_url"]

        return payload

    @staticmethod
    def session_from_tokens(
        payload: dict[str, object], steam_id: int | None = None
    ) -> SessionData:
        """Build a SessionData from a successful poll.

        A QR login does not report the SteamID, so it is read from the token's
        `sub` claim when the caller does not already know it.
        """
        access_token = str(payload["access_token"])
        refresh_token = payload.get("refresh_token")
        refresh_token = str(refresh_token) if refresh_token else None

        resolved = steam_id or SessionData.steam_id_from_token(
            refresh_token or access_token
        )
        if not resolved:
            raise SteamAuthError("Steam returned a token without a SteamID.")

        return SessionData(
            steam_id=resolved,
            access_token=access_token,
            refresh_token=refresh_token,
            session_id=SessionData.generate_session_id(),
        )

    # ── Token refresh ────────────────────────────────────────────────────

    async def refresh_access_token(self, session: SessionData) -> None:
        """Mint a new access token from the refresh token, in place."""
        if not session.refresh_token:
            raise NeedsReauthError("No refresh token stored.")

        body = await self._web.post(
            ApiEndpoints.AUTH_GENERATE_ACCESS_TOKEN,
            data={
                "refresh_token": session.refresh_token,
                "steamid": str(session.steam_id),
            },
        )

        payload = json.loads(body).get("response") or {}
        if not payload.get("access_token"):
            raise NeedsReauthError("Steam refused to refresh the access token.")

        session.access_token = str(payload["access_token"])
        if payload.get("refresh_token"):
            session.refresh_token = str(payload["refresh_token"])

    async def ensure_valid_session(self, session: SessionData | None) -> None:
        """Refresh the access token if it has expired.

        Steam rejects calls made with a stale token, so this runs before any
        authenticated request rather than after a confusing failure.
        """
        if session is None or not session.refresh_token:
            raise NeedsReauthError("This account has no stored session.")

        if session.is_refresh_token_expired():
            # Deliberately names no command: guests see this text too, and the
            # recovery differs by role. Callers add their own guidance.
            raise NeedsReauthError("The stored login has expired.")

        if session.is_access_token_expired():
            log.info("Refreshing access token for %s", session.steam_id)
            await self.refresh_access_token(session)
