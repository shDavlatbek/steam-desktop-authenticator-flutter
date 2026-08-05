"""Access gating for every incoming update.

Runs as an outer middleware so unauthorised users are turned away before any
handler, filter, or FSM state is consulted — a stranger who finds the bot can
learn nothing about it beyond that it exists.
"""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable
from typing import Any

from aiogram import BaseMiddleware
from aiogram.types import CallbackQuery, Message, TelegramObject

from .access import ShareRegistry

log = logging.getLogger(__name__)

_DENIED = "You do not have access to this bot."


class AccessMiddleware(BaseMiddleware):
    """Tags each update with its caller's role and drops everyone else."""

    def __init__(self, admin_id: int, shares: ShareRegistry) -> None:
        self._admin_id = admin_id
        self._shares = shares

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        user = data.get("event_from_user")
        if user is None:
            return None

        is_admin = user.id == self._admin_id
        shared_ids = self._shares.steam_ids_for(user.id)

        if not is_admin and not shared_ids:
            log.warning("Rejected update from unauthorised user %s", user.id)
            await _reject(event)
            return None

        data["is_admin"] = is_admin
        data["shared_steam_ids"] = shared_ids
        return await handler(event, data)


async def _reject(event: TelegramObject) -> None:
    try:
        if isinstance(event, Message):
            await event.answer(_DENIED)
        elif isinstance(event, CallbackQuery):
            await event.answer(_DENIED, show_alert=True)
    except Exception:  # noqa: BLE001 - never let a rejection raise
        log.debug("Could not deliver rejection notice", exc_info=True)
