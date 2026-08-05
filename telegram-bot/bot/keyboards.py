"""Inline and reply keyboards, plus the callback payload schemas."""

from __future__ import annotations

from aiogram.filters.callback_data import CallbackData
from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    KeyboardButton,
    KeyboardButtonRequestUsers,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
)
from aiogram.utils.keyboard import InlineKeyboardBuilder

from steamguard import Confirmation, SteamGuardAccount

# Telegram caps callback data at 64 bytes, which is why identifiers here are
# short tokens rather than Steam's uint64s where possible.


class AccountCB(CallbackData, prefix="acct"):
    action: str  # code | confs | share | export | remove | remove_ok
    steam_id: int


class ConfCB(CallbackData, prefix="cf"):
    action: str  # ok | no | ok_all | no_all
    steam_id: int
    conf_id: str


class QrCB(CallbackData, prefix="qr"):
    action: str  # pick | approve | deny
    token: str
    steam_id: int = 0


class ShareCB(CallbackData, prefix="sh"):
    action: str  # revoke
    steam_id: int
    user_id: int


class LoginCB(CallbackData, prefix="lg"):
    action: str  # cancel


def cancel_login_keyboard() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="Cancel", callback_data=LoginCB(action="cancel"))
    return builder.as_markup()


def accounts_keyboard(
    accounts: list[SteamGuardAccount], action: str
) -> InlineKeyboardMarkup:
    """One button per account, all triggering the same action."""
    builder = InlineKeyboardBuilder()
    for account in accounts:
        builder.button(
            text=account.display_name,
            callback_data=AccountCB(action=action, steam_id=account.steam_id),
        )
    builder.adjust(1)
    return builder.as_markup()


def account_menu(account: SteamGuardAccount) -> InlineKeyboardMarkup:
    """Everything the admin can do with one account."""
    builder = InlineKeyboardBuilder()
    steam_id = account.steam_id

    builder.button(
        text="Steam Guard code",
        callback_data=AccountCB(action="code", steam_id=steam_id),
    )
    builder.button(
        text="Confirmations",
        callback_data=AccountCB(action="confs", steam_id=steam_id),
    )
    builder.button(
        text="Re-login",
        callback_data=AccountCB(action="relogin", steam_id=steam_id),
    )
    builder.button(
        text="Share with…",
        callback_data=AccountCB(action="share", steam_id=steam_id),
    )
    builder.button(
        text="Export maFile",
        callback_data=AccountCB(action="export", steam_id=steam_id),
    )
    builder.button(
        text="Remove",
        callback_data=AccountCB(action="remove", steam_id=steam_id),
    )
    builder.adjust(2, 2, 2)
    return builder.as_markup()


def relogin_keyboard(steam_id: int) -> InlineKeyboardMarkup:
    """Offered wherever an expired session surfaces, so the fix is one tap
    away from the failure."""
    builder = InlineKeyboardBuilder()
    builder.button(
        text="Re-login with password",
        callback_data=AccountCB(action="relogin", steam_id=steam_id),
    )
    return builder.as_markup()


def confirmation_keyboard(
    steam_id: int, confirmation: Confirmation, show_bulk: bool
) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(
        text="Accept",
        callback_data=ConfCB(
            action="ok", steam_id=steam_id, conf_id=confirmation.id
        ),
    )
    builder.button(
        text="Deny",
        callback_data=ConfCB(
            action="no", steam_id=steam_id, conf_id=confirmation.id
        ),
    )
    if show_bulk:
        builder.button(
            text="Accept all",
            callback_data=ConfCB(action="ok_all", steam_id=steam_id, conf_id="0"),
        )
        builder.button(
            text="Deny all",
            callback_data=ConfCB(action="no_all", steam_id=steam_id, conf_id="0"),
        )
    builder.adjust(2, 2)
    return builder.as_markup()


def qr_decision_keyboard(token: str, steam_id: int) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(
        text="Approve login",
        callback_data=QrCB(action="approve", token=token, steam_id=steam_id),
    )
    builder.button(
        text="Deny",
        callback_data=QrCB(action="deny", token=token, steam_id=steam_id),
    )
    builder.adjust(2)
    return builder.as_markup()


def qr_account_picker(
    token: str, accounts: list[SteamGuardAccount]
) -> InlineKeyboardMarkup:
    """Which of the guest's shared accounts should approve this login."""
    builder = InlineKeyboardBuilder()
    for account in accounts:
        builder.button(
            text=account.display_name,
            callback_data=QrCB(
                action="pick", token=token, steam_id=account.steam_id
            ),
        )
    builder.adjust(1)
    return builder.as_markup()


def shares_keyboard(shares, account_name: str) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for share in shares:
        builder.button(
            text=f"Revoke {share.display_name}",
            callback_data=ShareCB(
                action="revoke", steam_id=share.steam_id, user_id=share.user_id
            ),
        )
    builder.adjust(1)
    return builder.as_markup()


def request_users_keyboard(request_id: int) -> ReplyKeyboardMarkup:
    """Opens Telegram's native contact picker.

    ``request_users`` needs a reply keyboard — it cannot be an inline button —
    so this replaces the keyboard for one step and is removed afterwards.
    """
    return ReplyKeyboardMarkup(
        keyboard=[
            [
                KeyboardButton(
                    text="Choose people",
                    request_users=KeyboardButtonRequestUsers(
                        request_id=request_id,
                        user_is_bot=False,
                        max_quantity=10,
                        request_name=True,
                        request_username=True,
                    ),
                )
            ],
            [KeyboardButton(text="Cancel")],
        ],
        resize_keyboard=True,
        one_time_keyboard=True,
    )


def remove_keyboard() -> ReplyKeyboardRemove:
    return ReplyKeyboardRemove()


def confirm_remove_keyboard(steam_id: int) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(
        text="Yes, remove it",
        callback_data=AccountCB(action="remove_ok", steam_id=steam_id),
    )
    builder.adjust(1)
    return builder.as_markup()


def button(text: str, callback_data: str) -> InlineKeyboardButton:
    return InlineKeyboardButton(text=text, callback_data=callback_data)
