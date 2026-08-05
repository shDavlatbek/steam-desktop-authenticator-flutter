"""Data models mirroring the .maFile and manifest.json formats.

JSON keys match the C# original exactly — snake_case throughout except the
nested Session object, which is PascalCase. Anything else breaks
interoperability with the desktop app and the original SDA.
"""

from __future__ import annotations

import base64
import binascii
import json
import secrets
import time
from dataclasses import dataclass, field
from typing import Any


def _decode_jwt_claims(token: str) -> dict[str, Any] | None:
    """Decode a JWT payload without verifying it.

    Steam is the issuer and we already trust the transport; these claims are
    read only to learn the SteamID and expiry, never to authorise anything.
    """
    try:
        parts = token.split(".")
        if len(parts) < 2:
            return None

        payload = parts[1].replace("-", "+").replace("_", "/")
        payload += "=" * (-len(payload) % 4)
        return json.loads(base64.b64decode(payload).decode("utf-8"))
    except (binascii.Error, ValueError, UnicodeDecodeError):
        return None


@dataclass
class SessionData:
    steam_id: int = 0
    access_token: str | None = None
    refresh_token: str | None = None
    session_id: str | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "SessionData":
        return cls(
            steam_id=int(data.get("SteamID") or 0),
            access_token=data.get("AccessToken"),
            refresh_token=data.get("RefreshToken"),
            session_id=data.get("SessionID"),
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "SteamID": self.steam_id,
            "AccessToken": self.access_token,
            "RefreshToken": self.refresh_token,
            "SessionID": self.session_id,
        }

    @staticmethod
    def generate_session_id() -> str:
        return secrets.token_hex(16)

    @staticmethod
    def steam_id_from_token(token: str) -> int | None:
        """Read the SteamID from a token's `sub` claim.

        A QR login never states the SteamID outright, so it has to come from
        the token itself.
        """
        claims = _decode_jwt_claims(token)
        if not claims or "sub" not in claims:
            return None
        try:
            return int(claims["sub"])
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _expiry(token: str | None) -> int | None:
        if not token:
            return None
        claims = _decode_jwt_claims(token)
        if not claims or "exp" not in claims:
            return None
        try:
            return int(claims["exp"])
        except (TypeError, ValueError):
            return None

    def is_access_token_expired(self) -> bool:
        exp = self._expiry(self.access_token)
        return exp is None or time.time() >= exp

    def is_refresh_token_expired(self) -> bool:
        exp = self._expiry(self.refresh_token)
        return exp is None or time.time() >= exp

    def cookies(self) -> dict[str, str]:
        """Cookie jar for steamcommunity.com, matching C# GetCookies()."""
        if not self.session_id:
            self.session_id = self.generate_session_id()
        return {
            "steamLoginSecure": f"{self.steam_id}%7C%7C{self.access_token or ''}",
            "sessionid": self.session_id,
            "mobileClient": "android",
            "mobileClientVersion": "777777 3.6.4",
        }


@dataclass
class SteamGuardAccount:
    shared_secret: str | None = None
    serial_number: str | None = None
    revocation_code: str | None = None
    uri: str | None = None
    server_time: int | None = None
    account_name: str | None = None
    token_gid: str | None = None
    identity_secret: str | None = None
    secret_1: str | None = None
    status: int | None = None
    device_id: str | None = None
    phone_number_hint: str | None = None
    confirm_type: int | None = None
    fully_enrolled: bool | None = None
    session: SessionData | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "SteamGuardAccount":
        session = data.get("Session")
        return cls(
            shared_secret=data.get("shared_secret"),
            serial_number=data.get("serial_number"),
            revocation_code=data.get("revocation_code"),
            uri=data.get("uri"),
            server_time=data.get("server_time"),
            account_name=data.get("account_name"),
            token_gid=data.get("token_gid"),
            identity_secret=data.get("identity_secret"),
            secret_1=data.get("secret_1"),
            status=data.get("status"),
            device_id=data.get("device_id"),
            phone_number_hint=data.get("phone_number_hint"),
            confirm_type=data.get("confirm_type"),
            fully_enrolled=data.get("fully_enrolled"),
            session=SessionData.from_json(session) if session else None,
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "shared_secret": self.shared_secret,
            "serial_number": self.serial_number,
            "revocation_code": self.revocation_code,
            "uri": self.uri,
            "server_time": self.server_time,
            "account_name": self.account_name,
            "token_gid": self.token_gid,
            "identity_secret": self.identity_secret,
            "secret_1": self.secret_1,
            "status": self.status,
            "device_id": self.device_id,
            "phone_number_hint": self.phone_number_hint,
            "confirm_type": self.confirm_type,
            "fully_enrolled": self.fully_enrolled,
            "Session": self.session.to_json() if self.session else None,
        }

    @property
    def steam_id(self) -> int:
        return self.session.steam_id if self.session else 0

    @property
    def display_name(self) -> str:
        return self.account_name or str(self.steam_id) or "unknown"

    def can_generate_codes(self) -> bool:
        return bool(self.shared_secret)

    def can_approve_logins(self) -> bool:
        """Approving needs a secret to sign with and a session to send it on."""
        return bool(self.shared_secret) and bool(
            self.session and self.session.refresh_token
        )


@dataclass
class ManifestEntry:
    steam_id: int
    filename: str
    salt: str | None = None
    iv: str | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "ManifestEntry":
        return cls(
            steam_id=int(data.get("steamid") or 0),
            filename=data.get("filename") or "",
            salt=data.get("encryption_salt"),
            iv=data.get("encryption_iv"),
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "encryption_iv": self.iv,
            "encryption_salt": self.salt,
            "filename": self.filename,
            "steamid": self.steam_id,
        }


@dataclass
class Manifest:
    encrypted: bool = False
    first_run: bool = True
    entries: list[ManifestEntry] = field(default_factory=list)
    periodic_checking: bool = False
    periodic_checking_interval: int = 5
    periodic_checking_checkall: bool = False
    auto_confirm_market_transactions: bool = False
    auto_confirm_trades: bool = False

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "Manifest":
        return cls(
            encrypted=bool(data.get("encrypted", False)),
            first_run=bool(data.get("first_run", True)),
            entries=[
                ManifestEntry.from_json(entry)
                for entry in data.get("entries", [])
            ],
            periodic_checking=bool(data.get("periodic_checking", False)),
            periodic_checking_interval=int(
                data.get("periodic_checking_interval", 5)
            ),
            periodic_checking_checkall=bool(
                data.get("periodic_checking_checkall", False)
            ),
            auto_confirm_market_transactions=bool(
                data.get("auto_confirm_market_transactions", False)
            ),
            auto_confirm_trades=bool(data.get("auto_confirm_trades", False)),
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "encrypted": self.encrypted,
            "first_run": self.first_run,
            "entries": [entry.to_json() for entry in self.entries],
            "periodic_checking": self.periodic_checking,
            "periodic_checking_interval": self.periodic_checking_interval,
            "periodic_checking_checkall": self.periodic_checking_checkall,
            "auto_confirm_market_transactions": (
                self.auto_confirm_market_transactions
            ),
            "auto_confirm_trades": self.auto_confirm_trades,
        }


@dataclass
class Confirmation:
    """A pending trade or market confirmation.

    All identifiers are strings: Steam's are uint64 and lose precision as
    anything narrower.
    """

    id: str
    nonce: str
    creator_id: str
    type: int
    headline: str
    summary: str
    icon: str | None = None
    accept_text: str = "Accept"
    cancel_text: str = "Cancel"

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "Confirmation":
        summary = data.get("summary") or []
        return cls(
            id=str(data.get("id", "")),
            nonce=str(data.get("nonce", "")),
            creator_id=str(data.get("creator_id", "")),
            type=int(data.get("type") or 0),
            headline=data.get("headline") or "Confirmation",
            summary=" · ".join(str(s) for s in summary) if summary else "",
            icon=data.get("icon"),
            accept_text=data.get("accept") or "Accept",
            cancel_text=data.get("cancel") or "Cancel",
        )

    @property
    def type_name(self) -> str:
        return {
            1: "Generic",
            2: "Trade",
            3: "Market listing",
            6: "Account recovery",
        }.get(self.type, f"Type {self.type}")
