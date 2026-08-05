"""Filters distinguishing the admin from guests."""

from __future__ import annotations

from aiogram.filters import BaseFilter
from aiogram.types import TelegramObject


class IsAdmin(BaseFilter):
    """Passes only for the configured admin.

    Reads the flag AccessMiddleware injected rather than comparing IDs again,
    so there is exactly one place that decides who the admin is.
    """

    async def __call__(
        self, event: TelegramObject, is_admin: bool = False, **_: object
    ) -> bool:
        return is_admin


class IsGuest(BaseFilter):
    """Passes for authorised non-admin users."""

    async def __call__(
        self, event: TelegramObject, is_admin: bool = False, **_: object
    ) -> bool:
        return not is_admin
