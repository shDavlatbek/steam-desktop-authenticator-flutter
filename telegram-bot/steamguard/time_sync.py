"""Clock alignment with Steam's servers.

TOTP codes and confirmation hashes are signed against Steam time, so a host
whose clock drifts by more than ~30s would otherwise produce codes that look
fine and are rejected. The offset is fetched once and reused.
"""

from __future__ import annotations

import json
import logging
import time

from .constants import ApiEndpoints
from .web import SteamWeb

log = logging.getLogger(__name__)


class SteamTime:
    def __init__(self, web: SteamWeb) -> None:
        self._web = web
        self._offset = 0
        self._aligned = False

    async def align(self) -> None:
        body = await self._web.post(
            ApiEndpoints.TWO_FACTOR_TIME_QUERY, data={"steamid": "0"}
        )
        payload = json.loads(body)["response"]
        server_time = int(payload["server_time"])

        self._offset = server_time - int(time.time())
        self._aligned = True
        log.info("Aligned with Steam time (offset %ds)", self._offset)

    async def current(self) -> int:
        """Current Unix timestamp adjusted to Steam's clock."""
        if not self._aligned:
            await self.align()
        return int(time.time()) + self._offset
