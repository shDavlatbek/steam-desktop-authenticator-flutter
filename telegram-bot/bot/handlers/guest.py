"""The guest surface: approve a QR login, and nothing else.

Every handler here re-checks the share registry rather than trusting the token
or callback payload. A grant revoked a second ago must not still work.
"""

from __future__ import annotations

import asyncio
import logging

from aiogram import Bot, F, Router, html
from aiogram.types import CallbackQuery, Message

from steamguard import (
    LoginApprovalError,
    NeedsReauthError,
    QrChallenge,
    SteamGuardAccount,
)
from steamguard.qr_image import decode_qr

from ..images import extract_image_bytes
from ..keyboards import (
    QrCB,
    qr_account_picker,
    qr_decision_keyboard,
    relogin_keyboard,
)
from ..pending import PendingQr
from ..services import Services

log = logging.getLogger(__name__)

router = Router(name="guest")

_NOT_A_STEAM_CODE = (
    "That does not look like a Steam login QR code. Open the Steam sign-in "
    "page, then send me a screenshot of the code it shows."
)
_NO_QR_FOUND = (
    "I could not find a QR code in that image. Make sure the whole code is "
    "visible, and try sending it as a <b>file</b> rather than a photo — "
    "Telegram compresses photos and that can blur the code."
)


@router.message(F.photo | F.document)
async def on_image(
    message: Message, bot: Bot, services: Services, is_admin: bool
) -> None:
    """A sent image is always interpreted as a login QR code."""
    image_bytes = await extract_image_bytes(message, bot)
    if image_bytes is None:
        return

    notice = await message.answer("Reading the code…")

    # OpenCV work is CPU-bound; off the loop so the bot stays responsive.
    payload = await asyncio.to_thread(decode_qr, image_bytes)
    if payload is None:
        await notice.edit_text(_NO_QR_FOUND)
        return

    challenge = QrChallenge.try_parse(payload)
    if challenge is None:
        await notice.edit_text(_NOT_A_STEAM_CODE)
        return

    accounts = _approvable_accounts(message.from_user.id, services, is_admin)
    if not accounts:
        stale = _expired_accounts(message.from_user.id, services, is_admin)
        if stale:
            # The owner is the only one who can fix this, so tell them rather
            # than leaving the guest stuck against a silent wall.
            await notice.edit_text(
                "That account's Steam login has expired, so I cannot sign you "
                "in. I have told the owner."
            )
            await _notify_expired(bot, services, message.from_user, stale)
            return

        await notice.edit_text(
            "No account can approve logins right now."
            if is_admin
            else "None of the accounts shared with you can approve logins "
            "right now. Ask the owner to check them."
        )
        return

    pending = services.pending_qr.add(message.from_user.id, challenge)

    if len(accounts) == 1:
        await _show_decision(notice, accounts[0], pending, services)
        return

    await notice.edit_text(
        "Which account should sign in?",
        reply_markup=qr_account_picker(pending.token, accounts),
    )


@router.callback_query(QrCB.filter(F.action == "pick"))
async def on_pick_account(
    query: CallbackQuery,
    callback_data: QrCB,
    services: Services,
    is_admin: bool,
) -> None:
    pending = services.pending_qr.get(callback_data.token, query.from_user.id)
    if pending is None:
        await query.answer("That request expired. Send the code again.", show_alert=True)
        return

    account = _authorised_account(
        query.from_user.id, callback_data.steam_id, services, is_admin
    )
    if account is None:
        await query.answer("You do not have access to that account.", show_alert=True)
        return

    await query.answer()
    await _show_decision(query.message, account, pending, services)


@router.callback_query(QrCB.filter(F.action.in_({"approve", "deny"})))
async def on_decision(
    query: CallbackQuery,
    callback_data: QrCB,
    bot: Bot,
    services: Services,
    is_admin: bool,
) -> None:
    approve = callback_data.action == "approve"

    # Popped: a login request is single-use, so a double tap cannot replay it.
    pending = services.pending_qr.pop(callback_data.token, query.from_user.id)
    if pending is None:
        await query.answer("That request expired. Send the code again.", show_alert=True)
        return

    account = _authorised_account(
        query.from_user.id, callback_data.steam_id, services, is_admin
    )
    if account is None:
        await query.answer("You do not have access to that account.", show_alert=True)
        return

    await query.answer()

    try:
        await services.auth.ensure_valid_session(account.session)
        await services.approval.respond(account, pending.challenge, approve)
        await services.persist(account)
    except NeedsReauthError:
        await query.message.edit_text(
            "That account's Steam login has expired, so I cannot sign you in. "
            "I have told the owner."
        )
        await _notify_expired(bot, services, query.from_user, [account])
        return
    except LoginApprovalError as exc:
        await query.message.edit_text(f"Steam refused: {html.quote(str(exc))}")
        await _notify_admin(
            bot, services, query, account, approved=False, error=str(exc)
        )
        return
    except Exception as exc:  # noqa: BLE001 - surface, do not crash the bot
        log.exception("Approval failed")
        await query.message.edit_text(
            f"Something went wrong: {html.quote(str(exc))}"
        )
        return

    await query.message.edit_text(
        "Login approved. You should be signed in now."
        if approve
        else "Login denied."
    )
    await _notify_admin(bot, services, query, account, approved=approve)


async def _show_decision(
    message: Message,
    account: SteamGuardAccount,
    pending: PendingQr,
    services: Services,
) -> None:
    """Fetch and present the login details before asking for a decision."""
    lines = [
        f"Sign in to {html.bold(html.quote(account.display_name))}?",
    ]

    try:
        await services.auth.ensure_valid_session(account.session)
        await services.persist(account)
        info = await services.approval.get_session_info(
            account.session.access_token, pending.challenge
        )
    except Exception as exc:  # noqa: BLE001
        # Details are a courtesy; a lookup failure should not block approval.
        log.warning("Could not fetch session info: %s", exc)
        info = None

    if info is not None:
        lines += [
            "",
            f"Device: {html.quote(info.device_name or 'Unknown')}",
            f"Platform: {info.platform_name}",
            f"Location: {html.quote(info.location)}",
            f"IP: {html.quote(info.ip or 'Unknown')}",
        ]
        if info.is_suspicious:
            lines += [
                "",
                "⚠️ Steam flagged this as unusual — an unfamiliar location or "
                "device. Deny it if it was not you.",
            ]

    await message.edit_text(
        "\n".join(lines),
        reply_markup=qr_decision_keyboard(pending.token, account.steam_id),
    )


def _visible_accounts(
    user_id: int, services: Services, is_admin: bool
) -> list[SteamGuardAccount]:
    if is_admin:
        return services.store.all_accounts()

    accounts = []
    for steam_id in services.shares.steam_ids_for(user_id):
        account = services.store.get(steam_id)
        if account is not None:
            accounts.append(account)
    return accounts


def _approvable_accounts(
    user_id: int, services: Services, is_admin: bool
) -> list[SteamGuardAccount]:
    """Accounts that can actually approve a login right now.

    Expired sessions are filtered out here so a guest is told up front rather
    than after picking an account and tapping Approve.
    """
    return [
        a
        for a in _visible_accounts(user_id, services, is_admin)
        if a.can_approve_logins() and not a.session.is_refresh_token_expired()
    ]


def _expired_accounts(
    user_id: int, services: Services, is_admin: bool
) -> list[SteamGuardAccount]:
    """Accounts that would work but for an expired login."""
    return [
        a
        for a in _visible_accounts(user_id, services, is_admin)
        if a.can_approve_logins() and a.session.is_refresh_token_expired()
    ]


def _authorised_account(
    user_id: int, steam_id: int, services: Services, is_admin: bool
) -> SteamGuardAccount | None:
    """Resolve an account only if the caller may still act on it.

    Re-checked on every callback rather than trusted from the payload, so a
    revoked share stops working immediately even mid-flow.
    """
    if not is_admin and not services.shares.is_allowed(user_id, steam_id):
        return None
    return services.store.get(steam_id)


async def _notify_expired(
    bot: Bot,
    services: Services,
    user,
    accounts: list[SteamGuardAccount],
) -> None:
    """Tell the owner an account needs a password re-login, with the button."""
    who = html.quote(user.full_name)
    if user.username:
        who += f" (@{html.quote(user.username)})"

    for account in accounts:
        try:
            await bot.send_message(
                services.config.admin_id,
                f"{who} tried to sign in to "
                f"{html.bold(html.quote(account.display_name))}, but its "
                "Steam login has expired.",
                reply_markup=relogin_keyboard(account.steam_id),
            )
        except Exception:  # noqa: BLE001
            log.warning("Could not notify admin about expiry", exc_info=True)


async def _notify_admin(
    bot: Bot,
    services: Services,
    query: CallbackQuery,
    account: SteamGuardAccount,
    approved: bool,
    error: str | None = None,
) -> None:
    """Tell the owner every time a guest acts. This is the audit trail."""
    user = query.from_user
    who = html.quote(user.full_name)
    if user.username:
        who += f" (@{html.quote(user.username)})"

    if error:
        outcome = f"failed — {html.quote(error)}"
    else:
        outcome = "approved a login" if approved else "denied a login"

    try:
        await bot.send_message(
            services.config.admin_id,
            f"{who} {outcome} for "
            f"{html.bold(html.quote(account.display_name))}.",
        )
    except Exception:  # noqa: BLE001
        log.warning("Could not notify admin", exc_info=True)
