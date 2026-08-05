"""Parsing the payload encoded in a Steam login QR code."""

from __future__ import annotations

import re
from dataclasses import dataclass

# Steam renders challenges as https://s.team/q/{version}/{client_id}. A trailing
# query string is allowed and ignored.
_URL_PATTERN = re.compile(r"^https?://s\.team/q/(\d+)/(\d+)(\?|$)")


@dataclass(frozen=True)
class QrChallenge:
    """A pending login identified by a scanned QR code.

    ``client_id`` stays a string because Steam's client IDs are uint64.
    """

    version: int
    client_id: str

    @classmethod
    def try_parse(cls, url: str | None) -> "QrChallenge | None":
        """Parse a scanned payload, or return None if it isn't a Steam login."""
        if not url:
            return None

        match = _URL_PATTERN.match(url.strip())
        if match is None:
            return None

        return cls(version=int(match.group(1)), client_id=match.group(2))
