"""Granting and revoking guest access, using Telegram's native user picker."""

from __future__ import annotations

import logging

from aiogram import Bot, F, Router, html
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..filters import IsAdmin
from ..keyboards import (
    AccountCB,
    ShareCB,
    accounts_keyboard,
    remove_keyboard,
    request_users_keyboard,
    shares_keyboard,
)
from ..services import Services
from ..states import ShareAccount

log = logging.getLogger(__name__)

router = Router(name="sharing")
router.message.filter(IsAdmin())
router.callback_query.filter(IsAdmin())

# The picker echoes this back in UsersShared.request_id. Which account the
# grant is for lives in FSM state instead, because a SteamID is 64-bit and
# request_id is only a signed 32-bit int.
_REQUEST_ID = 1


@router.message(Command("share"))
async def share_command(message: Message, services: Services) -> None:
    accounts = [
        a for a in services.store.all_accounts() if a.can_approve_logins()
    ]
    if not accounts:
        await message.answer(
            "No account can approve logins yet. An account needs both a "
            "shared secret and an active session — /import its .maFile, then "
            "sign it in."
        )
        return

    await message.answer(
        "Share which account?", reply_markup=accounts_keyboard(accounts, "share")
    )


@router.callback_query(AccountCB.filter(F.action == "share"))
async def begin_share(
    query: CallbackQuery,
    callback_data: AccountCB,
    state: FSMContext,
    services: Services,
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    if not account.can_approve_logins():
        await query.answer(
            "That account has no shared secret or no active session.",
            show_alert=True,
        )
        return

    await state.set_state(ShareAccount.choosing_users)
    await state.update_data(steam_id=account.steam_id)
    await query.answer()

    await query.message.answer(
        f"Choose who may approve logins for "
        f"{html.bold(html.quote(account.display_name))}.\n\n"
        "They will be able to sign this account in by sending me a QR code. "
        "They will <b>not</b> see Steam Guard codes, confirmations, or "
        "secrets.",
        reply_markup=request_users_keyboard(_REQUEST_ID),
    )


@router.message(ShareAccount.choosing_users, F.text.casefold() == "cancel")
async def cancel_share(message: Message, state: FSMContext) -> None:
    await state.clear()
    await message.answer("Cancelled.", reply_markup=remove_keyboard())


@router.message(ShareAccount.choosing_users, F.users_shared)
async def users_chosen(
    message: Message, state: FSMContext, bot: Bot, services: Services
) -> None:
    data = await state.get_data()
    steam_id = int(data.get("steam_id") or 0)
    await state.clear()

    account = services.store.get(steam_id)
    if account is None:
        await message.answer("That account is gone.", reply_markup=remove_keyboard())
        return

    granted: list[str] = []
    already: list[str] = []

    for user in _shared_users(message):
        user_id, display = user
        if services.shares.grant(user_id, steam_id, display):
            granted.append(display)
            await _greet(bot, user_id, account.display_name)
        else:
            already.append(display)

    lines = []
    if granted:
        lines.append(
            f"Shared {html.bold(html.quote(account.display_name))} with: "
            + ", ".join(html.quote(name) for name in granted)
        )
    if already:
        lines.append(
            "Already had access: "
            + ", ".join(html.quote(name) for name in already)
        )
    if not lines:
        lines.append("Nobody was selected.")

    await message.answer("\n".join(lines), reply_markup=remove_keyboard())


@router.message(Command("shares"))
async def list_shares(message: Message, services: Services) -> None:
    shares = services.shares.all_shares()
    if not shares:
        await message.answer("Nobody has access. Use /share to grant it.")
        return

    by_account: dict[int, list] = {}
    for share in shares:
        by_account.setdefault(share.steam_id, []).append(share)

    for steam_id, account_shares in by_account.items():
        account = services.store.get(steam_id)
        name = account.display_name if account else f"(removed {steam_id})"

        lines = [html.bold(html.quote(name))]
        for share in account_shares:
            lines.append(
                f"• {html.quote(share.display_name)} "
                f"({html.code(str(share.user_id))})"
            )

        await message.answer(
            "\n".join(lines),
            reply_markup=shares_keyboard(account_shares, name),
        )


@router.callback_query(ShareCB.filter(F.action == "revoke"))
async def revoke_share(
    query: CallbackQuery, callback_data: ShareCB, services: Services
) -> None:
    revoked = services.shares.revoke(callback_data.user_id, callback_data.steam_id)
    await query.answer("Revoked." if revoked else "Already revoked.")

    if revoked:
        await query.message.edit_text(
            f"Revoked access for {html.code(str(callback_data.user_id))}."
        )


def _shared_users(message: Message) -> list[tuple[int, str]]:
    """Normalise the picker's payload to (user_id, display name).

    Bot API 7.2 replaced the bare `user_ids` list with `users`; both shapes are
    accepted so the bot works against older Telegram clients too.
    """
    shared = message.users_shared
    if shared is None:
        return []

    if shared.users:
        result = []
        for user in shared.users:
            name = " ".join(
                part for part in (user.first_name, user.last_name) if part
            )
            if user.username:
                name = f"{name} (@{user.username})" if name else f"@{user.username}"
            result.append((user.user_id, name or str(user.user_id)))
        return result

    return [(user_id, str(user_id)) for user_id in (shared.user_ids or [])]


async def _greet(bot: Bot, user_id: int, account_name: str) -> None:
    """Tell the guest they were granted access, if they have opened the bot.

    Telegram forbids messaging a user who has never started the bot, so this
    is best-effort — the grant stands either way.
    """
    try:
        await bot.send_message(
            user_id,
            f"You can now approve Steam logins for "
            f"{html.bold(html.quote(account_name))}.\n\n"
            "Send me a screenshot of the Steam login QR code and I will sign "
            "you in.",
        )
    except Exception:  # noqa: BLE001
        log.info("Could not notify %s about their new share", user_id)
