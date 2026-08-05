"""Signing for trade/market confirmation requests.

Equivalent to `lib/core/crypto/confirmation_hash.dart`. The tag is truncated to
32 bytes and the timestamp is written big-endian, exactly as the C# original
does — Steam rejects anything else.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import struct
from urllib.parse import quote

MAX_TAG_BYTES = 32


def generate_for_time(
    identity_secret: str | None,
    timestamp: int,
    tag: str | None,
) -> str | None:
    """Return the URL-encoded base64 hash, or None if the secret is unusable."""
    if not identity_secret:
        return None

    try:
        key = base64.b64decode(identity_secret.replace("\\/", "/"))
    except (binascii.Error, ValueError):
        return None

    buffer = struct.pack(">Q", timestamp)
    if tag:
        buffer += tag.encode("utf-8")[:MAX_TAG_BYTES]

    digest = hmac.new(key, buffer, hashlib.sha1).digest()

    # safe="" so "+", "/" and "=" are all escaped. Dart's Uri.encodeComponent
    # differs on characters like "!" and "*", but base64 never produces those.
    return quote(base64.b64encode(digest).decode("ascii"), safe="")
