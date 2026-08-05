"""Commands available to whoever is allowed to talk to the bot."""

from __future__ import annotations

from aiogram import Router, html
from aiogram.filters import Command, CommandStart
from aiogram.fsm.context import FSMContext
from aiogram.types import Message

from ..keyboards import remove_keyboard
from ..services import Services

router = Router(name="common")

_ADMIN_HELP = """<b>Steam Guard bot — admin</b>

/accounts — list accounts and open their menu
/code — Steam Guard code for an account
/confirmations — pending trades and market listings
/login — sign in by scanning a QR code, no password
/import — import .maFile documents or a .zip of a maFiles folder
/share — give someone login-approval access
/shares — who currently has access
/cancel — abort the current step

When an account's Steam login expires, open it from /accounts and tap
<b>Re-login</b> — I ask only for the password and handle the Guard code myself.

Guests you share an account with can only approve QR logins for it.
"""

_GUEST_HELP = """<b>Steam login approval</b>

Send me a photo or screenshot of the Steam login QR code and I will approve
the sign-in for the account you were given access to.

You can approve logins. You cannot see Steam Guard codes, confirmations, or
anything else about the account.
"""


@router.message(CommandStart())
async def start(message: Message, is_admin: bool) -> None:
    await message.answer(_ADMIN_HELP if is_admin else _GUEST_HELP)


@router.message(Command("help"))
async def help_command(message: Message, is_admin: bool) -> None:
    await message.answer(_ADMIN_HELP if is_admin else _GUEST_HELP)


@router.message(Command("cancel"))
async def cancel(message: Message, state: FSMContext) -> None:
    current = await state.get_state()
    await state.clear()

    if current is None:
        await message.answer("Nothing to cancel.", reply_markup=remove_keyboard())
        return

    await message.answer("Cancelled.", reply_markup=remove_keyboard())


@router.message(Command("whoami"))
async def whoami(message: Message, is_admin: bool, services: Services) -> None:
    """Useful when setting ADMIN_ID for the first time."""
    role = "admin" if is_admin else "guest"
    shared = services.shares.steam_ids_for(message.from_user.id)

    lines = [
        f"Telegram ID: {html.code(str(message.from_user.id))}",
        f"Role: {role}",
    ]
    if not is_admin:
        lines.append(f"Accounts shared with you: {len(shared)}")

    await message.answer("\n".join(lines))
