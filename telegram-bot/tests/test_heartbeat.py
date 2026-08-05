"""The liveness signal behind the container healthcheck.

Worth testing precisely because it is the thing that decides whether a wedged
bot gets restarted or sits there looking healthy.
"""

from __future__ import annotations

import asyncio
import os
import time

import pytest

from bot import heartbeat
from bot.healthcheck import main as healthcheck_main


class TestHeartbeat:
    def test_beat_creates_the_file(self, tmp_path):
        heartbeat.beat(tmp_path)

        assert heartbeat.heartbeat_path(tmp_path).exists()

    def test_creates_the_directory_if_missing(self, tmp_path):
        nested = tmp_path / "does" / "not" / "exist"
        heartbeat.beat(nested)

        assert heartbeat.heartbeat_path(nested).exists()

    def test_age_is_none_before_the_first_beat(self, tmp_path):
        assert heartbeat.age_seconds(tmp_path) is None

    def test_age_is_small_right_after_a_beat(self, tmp_path):
        heartbeat.beat(tmp_path)

        age = heartbeat.age_seconds(tmp_path)
        assert age is not None and age < 5

    def test_not_alive_without_a_heartbeat(self, tmp_path):
        assert heartbeat.is_alive(tmp_path) is False

    def test_alive_after_a_beat(self, tmp_path):
        heartbeat.beat(tmp_path)

        assert heartbeat.is_alive(tmp_path) is True

    def test_a_stale_beat_is_not_alive(self, tmp_path):
        """The case that matters: the process lives, the loop does not."""
        heartbeat.beat(tmp_path)

        path = heartbeat.heartbeat_path(tmp_path)
        stale = time.time() - (heartbeat.STALE_AFTER_SECONDS + 60)
        os.utime(path, (stale, stale))

        assert heartbeat.is_alive(tmp_path) is False

    def test_a_beat_just_inside_the_window_is_alive(self, tmp_path):
        heartbeat.beat(tmp_path)

        path = heartbeat.heartbeat_path(tmp_path)
        recent = time.time() - (heartbeat.STALE_AFTER_SECONDS - 10)
        os.utime(path, (recent, recent))

        assert heartbeat.is_alive(tmp_path) is True

    def test_beat_survives_an_unwritable_directory(self, tmp_path):
        """A failed beat must not take the bot down with it."""
        blocked = tmp_path / "blocked"
        blocked.write_text("I am a file, not a directory")

        heartbeat.beat(blocked)  # must not raise

        assert heartbeat.age_seconds(blocked) is None

    async def test_run_beats_immediately_and_then_repeats(self, tmp_path):
        task = asyncio.create_task(heartbeat.run(tmp_path, interval=0.05))
        try:
            await asyncio.sleep(0.01)
            # Beats once before its first sleep, so a slow interval never
            # leaves the healthcheck failing at startup.
            assert heartbeat.heartbeat_path(tmp_path).exists()

            first = heartbeat.heartbeat_path(tmp_path).stat().st_mtime_ns
            await asyncio.sleep(0.2)
            assert heartbeat.heartbeat_path(tmp_path).stat().st_mtime_ns > first
        finally:
            task.cancel()
            with pytest.raises(asyncio.CancelledError):
                await task


class TestHealthcheckCommand:
    def test_fails_when_there_is_no_heartbeat(self, tmp_path, monkeypatch):
        monkeypatch.setenv("DATA_DIR", str(tmp_path))

        assert healthcheck_main() == 1

    def test_passes_with_a_fresh_heartbeat(self, tmp_path, monkeypatch):
        monkeypatch.setenv("DATA_DIR", str(tmp_path))
        heartbeat.beat(tmp_path)

        assert healthcheck_main() == 0

    def test_fails_with_a_stale_heartbeat(self, tmp_path, monkeypatch):
        monkeypatch.setenv("DATA_DIR", str(tmp_path))
        heartbeat.beat(tmp_path)

        path = heartbeat.heartbeat_path(tmp_path)
        stale = time.time() - (heartbeat.STALE_AFTER_SECONDS + 60)
        os.utime(path, (stale, stale))

        assert healthcheck_main() == 1
