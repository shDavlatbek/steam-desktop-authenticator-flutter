"""Liveness signal for the container healthcheck.

`restart: unless-stopped` only notices a process that has *died*. A polling
loop that wedges — a hung socket, a deadlock — leaves the process alive and the
bot useless, and nothing would ever restart it.

So a background task touches a file on the event loop. If the loop stops
turning, the file goes stale and the healthcheck fails.

Kept free of heavy imports: `bot.healthcheck` runs this on every probe, and
pulling in aiogram and OpenCV would make each one cost seconds.
"""

from __future__ import annotations

import asyncio
import logging
import time
from pathlib import Path

log = logging.getLogger(__name__)

HEARTBEAT_FILENAME = ".heartbeat"

# Written this often; considered dead at STALE_AFTER_SECONDS. The gap absorbs
# ordinary scheduling jitter without masking a real hang for long.
INTERVAL_SECONDS = 30
STALE_AFTER_SECONDS = 120


def heartbeat_path(data_dir: str | Path) -> Path:
    return Path(data_dir) / HEARTBEAT_FILENAME


def age_seconds(data_dir: str | Path) -> float | None:
    """Seconds since the last beat, or None if there has never been one."""
    path = heartbeat_path(data_dir)
    try:
        return max(0.0, time.time() - path.stat().st_mtime)
    except OSError:
        return None


def is_alive(data_dir: str | Path, stale_after: int = STALE_AFTER_SECONDS) -> bool:
    age = age_seconds(data_dir)
    return age is not None and age <= stale_after


def beat(data_dir: str | Path) -> None:
    path = heartbeat_path(data_dir)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    except OSError:
        log.warning("Could not write heartbeat to %s", path, exc_info=True)


async def run(data_dir: str | Path, interval: int = INTERVAL_SECONDS) -> None:
    """Beat until cancelled. Intended to run as a background task."""
    beat(data_dir)
    while True:
        await asyncio.sleep(interval)
        beat(data_dir)
