"""FSM states for the multi-step admin flows."""

from __future__ import annotations

from aiogram.fsm.state import State, StatesGroup


class Relogin(StatesGroup):
    """Refreshing an account whose stored session has expired.

    Only the password is asked for — the username comes from the maFile, and
    the Steam Guard code is generated from the stored shared secret.
    """

    waiting_password = State()
    waiting_email_code = State()


class ImportAccount(StatesGroup):
    waiting_file = State()


class ShareAccount(StatesGroup):
    """Picking guests for an account via Telegram's native user chooser."""

    choosing_users = State()
