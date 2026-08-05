"""Password-free sign-in for the admin.

The bot renders a Steam challenge as a QR code, the admin scans it with the
official Steam mobile app, and the tokens arrive by polling. No password is
typed into Telegram, which also means none is left in the chat history.

Doubles as "log in again": an existing account keeps its secrets and only has
its session replaced.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging

from aiogram import Bot, F, Router, html
from aiogram.filters import Command
from aiogram.types import (
    BufferedInputFile,
    CallbackQuery,
    InputMediaPhoto,
    Message,
)

from steamguard import QrRenderError, SteamAuthError, render_qr_png

from ..filters import IsAdmin
from ..keyboards import LoginCB, cancel_login_keyboard
from ..services import Services

log = logging.getLogger(__name__)

router = Router(name="admin_login")
router.message.filter(IsAdmin())
router.callback_query.filter(IsAdmin())

# Steam expires a challenge well before this; the cap just stops a forgotten
# /login from polling forever.
_ATTEMPT_WINDOW_SECONDS = 180

# Consecutive poll failures tolerated. Steam returns transient errors while a
# session is pending, so one failure means nothing.
_MAX_CONSECUTIVE_FAILURES = 5

# One in-flight login per admin. Keyed by user so a second /login supersedes
# the first rather than racing it.
_active: dict[int, asyncio.Task] = {}


@router.message(Command("login"))
async def login_command(message: Message, bot: Bot, services: Services) -> None:
    if message.from_user is None:
        return
    _cancel_existing(message.from_user.id)

    notice = await message.answer("Asking Steam for a login code…")

    try:
        session = await services.auth.begin_with_qr(device_name="SDA Telegram Bot")
        if not session.challenge_url:
            raise SteamAuthError("Steam returned no challenge URL.")
        png = render_qr_png(session.challenge_url)
    except (SteamAuthError, QrRenderError) as exc:
        await notice.edit_text(html.quote(str(exc)))
        return
    except Exception as exc:  # noqa: BLE001
        log.exception("Could not start QR login")
        await notice.edit_text(f"Could not start: {html.quote(str(exc))}")
        return

    await notice.delete()
    photo = await message.answer_photo(
        BufferedInputFile(png, filename="steam-login.png"),
        caption=_caption("Scan this with the Steam mobile app to sign in."),
        reply_markup=cancel_login_keyboard(),
    )

    user_id = message.from_user.id
    task = asyncio.create_task(
        _poll_until_resolved(bot, photo, session, services),
        name=f"qr-login-{user_id}",
    )
    _active[user_id] = task
    task.add_done_callback(lambda _task, uid=user_id: _active.pop(uid, None))


@router.callback_query(LoginCB.filter(F.action == "cancel"))
async def cancel_login(query: CallbackQuery, bot: Bot) -> None:
    cancelled = _cancel_existing(query.from_user.id)
    await query.answer("Cancelled." if cancelled else "Nothing in progress.")

    if query.message is None:
        return

    with contextlib.suppress(Exception):
        await bot.edit_message_caption(
            chat_id=query.message.chat.id,
            message_id=query.message.message_id,
            caption="Sign-in cancelled.",
        )


async def _poll_until_resolved(
    bot: Bot, photo: Message, session, services: Services
) -> None:
    """Poll for tokens, refreshing the displayed QR when Steam rotates it."""
    deadline = asyncio.get_running_loop().time() + _ATTEMPT_WINDOW_SECONDS
    shown_url = session.challenge_url
    announced_scan = False
    failures = 0

    try:
        while True:
            await asyncio.sleep(session.interval)

            if asyncio.get_running_loop().time() > deadline:
                await _finish(bot, photo, "That code expired. Send /login again.")
                return

            try:
                payload = await services.auth.poll(session)
                failures = 0
            except Exception as exc:  # noqa: BLE001
                failures += 1
                log.warning("QR login poll failed (%d): %s", failures, exc)
                if failures >= _MAX_CONSECUTIVE_FAILURES:
                    await _finish(bot, photo, "Lost contact with Steam.")
                    return
                continue

            if payload.get("access_token"):
                await _complete(bot, photo, payload, services)
                return

            # Steam rotates the challenge; the picture has to follow or the
            # admin ends up scanning a code that is no longer valid.
            if session.challenge_url != shown_url:
                shown_url = session.challenge_url
                await _replace_qr(bot, photo, shown_url, announced_scan)

            if payload.get("had_remote_interaction") and not announced_scan:
                announced_scan = True
                await _edit_caption(
                    bot, photo, "Scanned — now approve the login on your phone."
                )

    except asyncio.CancelledError:
        raise
    except Exception:  # noqa: BLE001
        log.exception("QR login loop failed")
        await _finish(bot, photo, "Sign-in failed unexpectedly.")


async def _complete(
    bot: Bot, photo: Message, payload: dict, services: Services
) -> None:
    try:
        account, created = await services.store_login(payload)
    except SteamAuthError as exc:
        await _finish(bot, photo, html.quote(str(exc)))
        return

    name = html.bold(html.quote(account.display_name))
    if created:
        text = (
            f"Signed in as {name} and stored.\n\n"
            "Import its .maFile to enable Steam Guard codes and confirmations."
        )
    else:
        text = f"Signed in as {name}. Session refreshed."

    await _finish(bot, photo, text)


async def _replace_qr(
    bot: Bot, photo: Message, url: str, announced_scan: bool
) -> None:
    try:
        png = render_qr_png(url)
    except QrRenderError:
        log.warning("Could not render the rotated QR code")
        return

    caption = _caption(
        "Scanned — now approve the login on your phone."
        if announced_scan
        else "Scan this with the Steam mobile app to sign in."
    )

    with contextlib.suppress(Exception):
        await bot.edit_message_media(
            chat_id=photo.chat.id,
            message_id=photo.message_id,
            media=InputMediaPhoto(
                media=BufferedInputFile(png, filename="steam-login.png"),
                caption=caption,
            ),
            reply_markup=cancel_login_keyboard(),
        )


async def _edit_caption(bot: Bot, photo: Message, text: str) -> None:
    with contextlib.suppress(Exception):
        await bot.edit_message_caption(
            chat_id=photo.chat.id,
            message_id=photo.message_id,
            caption=_caption(text),
            reply_markup=cancel_login_keyboard(),
        )


async def _finish(bot: Bot, photo: Message, text: str) -> None:
    """Final state: drop the Cancel button so nothing looks actionable."""
    with contextlib.suppress(Exception):
        await bot.edit_message_caption(
            chat_id=photo.chat.id, message_id=photo.message_id, caption=text
        )


def _caption(text: str) -> str:
    return f"{text}\n\nThe code refreshes on its own — just scan whatever is shown."


def _cancel_existing(user_id: int) -> bool:
    task = _active.pop(user_id, None)
    if task is None or task.done():
        return False
    task.cancel()
    return True
