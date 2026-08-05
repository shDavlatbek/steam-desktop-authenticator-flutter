"""Container healthcheck: `python -m bot.healthcheck`.

Exits 0 while the bot's event loop is still turning, 1 once its heartbeat has
gone stale. Deliberately imports nothing heavy so a probe costs milliseconds.
"""

from __future__ import annotations

import os
import sys

from .heartbeat import STALE_AFTER_SECONDS, age_seconds


def main() -> int:
    data_dir = os.getenv("DATA_DIR", "./data")
    age = age_seconds(data_dir)

    if age is None:
        print(f"no heartbeat in {data_dir}", file=sys.stderr)
        return 1

    if age > STALE_AFTER_SECONDS:
        print(f"heartbeat is {age:.0f}s old (limit {STALE_AFTER_SECONDS}s)",
              file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
