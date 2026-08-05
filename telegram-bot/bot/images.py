"""Pulling image bytes out of an incoming message."""

from __future__ import annotations

import logging

from aiogram import Bot
from aiogram.types import Message

log = logging.getLogger(__name__)

# Telegram's Bot API refuses downloads above 20MB.
MAX_DOWNLOAD_BYTES = 20 * 1024 * 1024


async def extract_image_bytes(message: Message, bot: Bot) -> bytes | None:
    """Return the bytes of a photo or image document, or None.

    Photos are re-encoded by Telegram as fairly lossy JPEG. That is usually
    still readable, but sending the screenshot as a *file* preserves it
    exactly — worth suggesting when a decode fails.
    """
    file_id: str | None = None
    file_size: int | None = None

    if message.photo:
        largest = message.photo[-1]
        file_id, file_size = largest.file_id, largest.file_size
    elif message.document:
        mime = message.document.mime_type or ""
        if mime.startswith("image/"):
            file_id = message.document.file_id
            file_size = message.document.file_size

    if file_id is None:
        return None

    if file_size and file_size > MAX_DOWNLOAD_BYTES:
        log.warning("Refusing to download %d byte image", file_size)
        return None

    try:
        buffer = await bot.download(file_id)
    except Exception:  # noqa: BLE001 - network/file errors are not fatal here
        log.exception("Failed to download image %s", file_id)
        return None

    if buffer is None:
        return None
    return buffer.read()
