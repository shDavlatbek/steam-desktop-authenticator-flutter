"""Steam Guard TOTP code generation.

Byte-for-byte equivalent to `lib/core/crypto/steam_totp.dart` in the desktop
app, which is itself a port of SteamGuardAccount.GenerateSteamGuardCodeForTime()
from the original C#. Codes produced here must match the ones the app and the
official Steam client show for the same account and second.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import struct

from .constants import CODE_ALPHABET, TOTP_CODE_LENGTH, TOTP_PERIOD


def generate_code(shared_secret: str | None, timestamp: int) -> str:
    """Return the 5-character Steam Guard code for ``timestamp``.

    ``timestamp`` must be Steam-aligned time, not the local clock.
    Returns an empty string when the secret is missing or malformed, matching
    the desktop app rather than raising into the UI.
    """
    if not shared_secret:
        return ""

    try:
        # maFiles may carry JSON-escaped secrets ("\/" for "/").
        key = base64.b64decode(shared_secret.replace("\\/", "/"))
    except (binascii.Error, ValueError):
        return ""

    time_chunk = timestamp // TOTP_PERIOD
    digest = hmac.new(key, struct.pack(">Q", time_chunk), hashlib.sha1).digest()

    # Dynamic truncation: the low nibble of the last byte picks the offset.
    begin = digest[19] & 0x0F
    code_point = struct.unpack(">I", digest[begin : begin + 4])[0] & 0x7FFFFFFF

    alphabet_len = len(CODE_ALPHABET)
    chars = []
    for _ in range(TOTP_CODE_LENGTH):
        chars.append(CODE_ALPHABET[code_point % alphabet_len])
        code_point //= alphabet_len

    return bytes(chars).decode("ascii")


def seconds_remaining(timestamp: int) -> int:
    """Seconds until the current code rolls over."""
    return TOTP_PERIOD - (timestamp % TOTP_PERIOD)
