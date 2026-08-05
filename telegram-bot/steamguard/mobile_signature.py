"""Signing approval of another device's QR login.

Equivalent to `lib/core/crypto/mobile_confirmation_signature.dart`.

    message (18 bytes, little-endian):
      [0..1]   version    uint16
      [2..9]   client_id  uint64
      [10..17] steamid    uint64
    signature = HMAC-SHA256(base64decode(shared_secret), message)

Wrong byte order or field widths yield a well-formed signature that Steam
silently rejects, so verify against the reference implementations rather than
refactoring by intuition.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import struct

MAX_UINT64 = (1 << 64) - 1
MAX_UINT16 = (1 << 16) - 1


def generate(
    shared_secret: str,
    version: int,
    client_id: int | str,
    steam_id: int | str,
) -> bytes:
    """Return the raw 32-byte HMAC-SHA256 signature.

    ``client_id`` and ``steam_id`` accept strings so callers can pass Steam's
    uint64 values through without going near a float.
    """
    if not shared_secret:
        raise ValueError("shared_secret is required")
    if not 0 <= version <= MAX_UINT16:
        raise ValueError(f"version {version} does not fit in a uint16")

    client_id = _as_uint64(client_id, "client_id")
    steam_id = _as_uint64(steam_id, "steam_id")

    try:
        key = base64.b64decode(shared_secret.replace("\\/", "/"))
    except (binascii.Error, ValueError) as exc:
        raise ValueError("shared_secret is not valid base64") from exc

    message = struct.pack("<HQQ", version, client_id, steam_id)
    return hmac.new(key, message, hashlib.sha256).digest()


def generate_base64(
    shared_secret: str,
    version: int,
    client_id: int | str,
    steam_id: int | str,
) -> str:
    """The signature base64-encoded, as Steam's form-encoded API expects."""
    return base64.b64encode(
        generate(shared_secret, version, client_id, steam_id)
    ).decode("ascii")


def _as_uint64(value: int | str, name: str) -> int:
    try:
        parsed = int(str(value).strip())
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} is not an integer") from exc

    if not 0 <= parsed <= MAX_UINT64:
        raise ValueError(f"{name} does not fit in a uint64")
    return parsed
