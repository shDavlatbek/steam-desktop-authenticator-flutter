"""Entry point: python -m bot"""

from __future__ import annotations

import asyncio
import contextlib
import logging

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.fsm.storage.memory import MemoryStorage

from steamguard import WrongPasskeyError

from . import heartbeat
from .config import Config
from .handlers import build_router
from .middlewares import AccessMiddleware
from .services import Services

log = logging.getLogger(__name__)


async def run() -> None:
    config = Config.from_env()
    services = Services(config)

    try:
        await services.start()
    except WrongPasskeyError as exc:
        raise SystemExit(f"Could not open stored accounts: {exc}") from exc

    bot = Bot(
        token=config.bot_token,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )

    # In-memory FSM: the only things held are half-finished login flows, which
    # should not survive a restart anyway.
    dispatcher = Dispatcher(storage=MemoryStorage())
    dispatcher["services"] = services

    access = AccessMiddleware(config.admin_id, services.shares)
    dispatcher.message.outer_middleware(access)
    dispatcher.callback_query.outer_middleware(access)

    dispatcher.include_router(build_router())

    log.info("Admin is %s; data in %s", config.admin_id, config.data_dir)

    # Runs on the same loop as polling, so it stops beating the moment the
    # loop stops turning — which is the failure the healthcheck exists to see.
    pulse = asyncio.create_task(heartbeat.run(config.data_dir), name="heartbeat")

    try:
        # Drop anything queued while the bot was down — a stale QR approval is
        # worse than a missed one.
        await bot.delete_webhook(drop_pending_updates=True)
        await dispatcher.start_polling(bot)
    finally:
        pulse.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await pulse
        await services.stop()
        await bot.session.close()


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
    )
    # aiohttp is chatty at DEBUG and would log request URLs containing tokens.
    logging.getLogger("aiohttp").setLevel(logging.WARNING)

    try:
        asyncio.run(run())
    except (KeyboardInterrupt, SystemExit):
        log.info("Shutting down")


if __name__ == "__main__":
    main()
