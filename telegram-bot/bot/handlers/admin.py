"""Everything only the owner can do: accounts, codes, confirmations, storage."""

from __future__ import annotations

import asyncio
import contextlib
import logging

from aiogram import Bot, F, Router, html
from aiogram.filters import Command, CommandObject
from aiogram.fsm.context import FSMContext
from aiogram.types import BufferedInputFile, CallbackQuery, Message

from steamguard import (
    ConfirmationError,
    NeedsReauthError,
    SessionData,
    SteamAuthError,
    import_archive,
    import_mafiles,
)
from steamguard.auth import AuthSession
from steamguard.constants import GUARD_TYPE_DEVICE_CODE, GUARD_TYPE_EMAIL_CODE
from steamguard.totp import generate_code, seconds_remaining

from ..filters import IsAdmin
from ..images import MAX_DOWNLOAD_BYTES
from ..keyboards import (
    AccountCB,
    ConfCB,
    account_menu,
    accounts_keyboard,
    confirm_remove_keyboard,
    confirmation_keyboard,
    relogin_keyboard,
)
from ..services import Services
from ..states import ImportAccount, Relogin

log = logging.getLogger(__name__)

router = Router(name="admin")
# Every handler in this router requires the admin flag, on both update types.
router.message.filter(IsAdmin())
router.callback_query.filter(IsAdmin())


# ── Account list ─────────────────────────────────────────────────────────


@router.message(Command("accounts"))
async def list_accounts(message: Message, services: Services) -> None:
    accounts = services.store.all_accounts()
    if not accounts:
        await message.answer(
            "No accounts yet. Use /import to load .maFile accounts, or "
            "/login to sign one in."
        )
        return

    expired = 0
    lines = [f"<b>{len(accounts)} account(s)</b>", ""]
    for account in accounts:
        shares = services.shares.shares_for_account(account.steam_id)
        notes = []
        if _is_expired(account):
            notes.append("session expired")
            expired += 1
        if shares:
            notes.append(f"shared with {len(shares)}")

        suffix = f" — {', '.join(notes)}" if notes else ""
        lines.append(f"• {html.quote(account.display_name)}{suffix}")

    if expired:
        lines += [
            "",
            f"⚠️ {expired} account(s) need re-login. Open one and tap "
            "<b>Re-login</b>.",
        ]

    await message.answer(
        "\n".join(lines), reply_markup=accounts_keyboard(accounts, "menu")
    )


@router.callback_query(AccountCB.filter(F.action == "menu"))
async def open_menu(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    shares = services.shares.shares_for_account(account.steam_id)
    lines = [
        html.bold(html.quote(account.display_name)),
        f"SteamID: {html.code(str(account.steam_id))}",
        f"Session: {_session_status(account)}",
        f"Codes: {'yes' if account.can_generate_codes() else 'no shared secret'}",
        f"Confirmations: "
        f"{'yes' if account.identity_secret else 'no identity secret'}",
        f"Shared with: {len(shares)}",
    ]
    await query.message.edit_text(
        "\n".join(lines), reply_markup=account_menu(account)
    )
    await query.answer()


# ── Steam Guard codes ────────────────────────────────────────────────────


def _is_expired(account) -> bool:
    """Whether the account needs a password re-login.

    An expired *access* token is routine and refreshes itself; an expired
    *refresh* token is the one that cannot be recovered without a password.
    """
    session = account.session
    return session is None or session.is_refresh_token_expired()


def _session_status(account) -> str:
    session = account.session
    if session is None:
        return "none stored"
    if session.is_refresh_token_expired():
        return "⚠️ expired — re-login needed"
    if session.is_access_token_expired():
        return "ok (will refresh on use)"
    return "ok"


@router.message(Command("code"))
async def code_command(message: Message, services: Services) -> None:
    accounts = [a for a in services.store.all_accounts() if a.can_generate_codes()]
    if not accounts:
        await message.answer("No account has a shared secret.")
        return
    await message.answer(
        "Which account?", reply_markup=accounts_keyboard(accounts, "code")
    )


@router.callback_query(AccountCB.filter(F.action == "code"))
async def send_code(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None or not account.can_generate_codes():
        await query.answer("That account cannot generate codes.", show_alert=True)
        return

    timestamp = await services.clock.current()
    code = generate_code(account.shared_secret, timestamp)

    await query.message.edit_text(
        f"{html.bold(html.quote(account.display_name))}\n\n"
        f"{html.code(code)}\n\n"
        f"Valid for {seconds_remaining(timestamp)}s."
    )
    await query.answer()


# ── Confirmations ────────────────────────────────────────────────────────


@router.message(Command("confirmations"))
async def confirmations_command(message: Message, services: Services) -> None:
    accounts = [a for a in services.store.all_accounts() if a.identity_secret]
    if not accounts:
        await message.answer("No account has an identity secret.")
        return
    await message.answer(
        "Which account?", reply_markup=accounts_keyboard(accounts, "confs")
    )


@router.callback_query(AccountCB.filter(F.action == "confs"))
async def show_confirmations(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    await query.answer()
    await query.message.edit_text("Fetching confirmations…")

    try:
        confirmations = await services.confirmations.fetch(account)
        await services.persist(account)
    except NeedsReauthError as exc:
        await query.message.edit_text(
            f"{html.quote(str(exc))} Sign in again to continue.",
            reply_markup=relogin_keyboard(account.steam_id),
        )
        return
    except ConfirmationError as exc:
        await query.message.edit_text(html.quote(str(exc)))
        return
    except Exception as exc:  # noqa: BLE001
        log.exception("Confirmation fetch failed")
        await query.message.edit_text(f"Failed: {html.quote(str(exc))}")
        return

    if not confirmations:
        await query.message.edit_text(
            f"No pending confirmations for "
            f"{html.bold(html.quote(account.display_name))}."
        )
        return

    await query.message.edit_text(
        f"{len(confirmations)} pending for "
        f"{html.bold(html.quote(account.display_name))}:"
    )

    show_bulk = len(confirmations) > 1
    for confirmation in confirmations:
        text = (
            f"{html.bold(html.quote(confirmation.headline))}\n"
            f"{html.quote(confirmation.summary)}\n"
            f"<i>{confirmation.type_name}</i>"
        )
        await query.message.answer(
            text,
            reply_markup=confirmation_keyboard(
                account.steam_id, confirmation, show_bulk
            ),
        )


@router.callback_query(ConfCB.filter())
async def respond_to_confirmation(
    query: CallbackQuery, callback_data: ConfCB, services: Services
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    accept = callback_data.action in {"ok", "ok_all"}
    bulk = callback_data.action.endswith("_all")
    await query.answer()

    try:
        # Re-fetch: the stored list may be stale, and bulk needs every nonce.
        pending = await services.confirmations.fetch(account)
        if bulk:
            await services.confirmations.respond_all(account, pending, accept)
            outcome = f"{'Accepted' if accept else 'Denied'} all {len(pending)}."
        else:
            target = next(
                (c for c in pending if c.id == callback_data.conf_id), None
            )
            if target is None:
                await query.message.edit_text("That confirmation is no longer pending.")
                return
            await services.confirmations.respond(account, target, accept)
            outcome = "Accepted." if accept else "Denied."

        await services.persist(account)
    except NeedsReauthError as exc:
        await query.message.edit_text(
            f"{html.quote(str(exc))} Sign in again to continue.",
            reply_markup=relogin_keyboard(account.steam_id),
        )
        return
    except ConfirmationError as exc:
        await query.message.edit_text(html.quote(str(exc)))
        return
    except Exception as exc:  # noqa: BLE001
        log.exception("Confirmation response failed")
        await query.message.edit_text(f"Failed: {html.quote(str(exc))}")
        return

    await query.message.edit_text(outcome)


# ── Export / remove ──────────────────────────────────────────────────────


@router.callback_query(AccountCB.filter(F.action == "export"))
async def export_account(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    payload = services.store.export_mafile(callback_data.steam_id)
    if payload is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    await query.answer()
    await query.message.answer_document(
        BufferedInputFile(payload, filename=f"{callback_data.steam_id}.maFile"),
        caption=(
            "⚠️ This file contains the shared and identity secrets in "
            "plaintext. Anyone holding it controls the authenticator."
        ),
    )


@router.callback_query(AccountCB.filter(F.action == "remove"))
async def confirm_remove(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    await query.message.edit_text(
        f"Remove {html.bold(html.quote(account.display_name))}?\n\n"
        "Its .maFile is deleted and every share for it is revoked. Export it "
        "first if you might want it back.",
        reply_markup=confirm_remove_keyboard(account.steam_id),
    )
    await query.answer()


@router.callback_query(AccountCB.filter(F.action == "remove_ok"))
async def remove_account(
    query: CallbackQuery, callback_data: AccountCB, services: Services
) -> None:
    removed = await services.store.remove_account(callback_data.steam_id)
    revoked = services.shares.revoke_account(callback_data.steam_id)

    if not removed:
        await query.answer("That account is gone.", show_alert=True)
        return

    await query.message.edit_text(
        f"Removed. {revoked} share(s) revoked." if revoked else "Removed."
    )
    await query.answer()


# ── Import ───────────────────────────────────────────────────────────────


@router.message(Command("import"))
async def import_command(
    message: Message, command: CommandObject, state: FSMContext
) -> None:
    # A passkey given here decrypts archived accounts; it is unrelated to
    # SDA_PASSKEY, which is applied when they are written back out.
    passkey = (command.args or "").strip() or None

    await state.set_state(ImportAccount.waiting_file)
    await state.update_data(passkey=passkey, imported=0)

    lines = [
        "Send accounts to import. You can send:",
        "",
        "• any number of <b>.maFile</b> documents, one after another",
        "• a <b>.zip</b> of an entire <code>maFiles</code> folder",
        "",
        "A zip that includes its <code>manifest.json</code> can be decrypted "
        "here — run <code>/import your-passkey</code> to supply the key. A "
        "lone encrypted .maFile cannot, because its salt and IV live in that "
        "manifest.",
        "",
        "/done when finished, /cancel to abort.",
    ]
    if passkey:
        lines.insert(0, "Passkey set for this import.\n")

    await message.answer("\n".join(lines))


@router.message(ImportAccount.waiting_file, Command("done"))
async def import_done(message: Message, state: FSMContext) -> None:
    data = await state.get_data()
    total = int(data.get("imported") or 0)
    await state.clear()

    await message.answer(
        f"Import finished — {total} account(s) added."
        if total
        else "Import finished. Nothing was imported."
    )


@router.message(ImportAccount.waiting_file, F.document)
async def import_file(
    message: Message, bot: Bot, state: FSMContext, services: Services
) -> None:
    """Handle one document. Telegram delivers an album as separate updates, so
    sending twenty files at once simply runs this twenty times."""
    document = message.document
    if document.file_size and document.file_size > MAX_DOWNLOAD_BYTES:
        await message.answer(
            f"{html.quote(document.file_name or 'That file')} is too large "
            "for Telegram to hand over (20MB limit)."
        )
        return

    buffer = await bot.download(document.file_id)
    if buffer is None:
        await message.answer("Could not download that file.")
        return

    raw = buffer.read()
    filename = document.file_name or "upload"
    data = await state.get_data()
    passkey = data.get("passkey")

    try:
        if filename.lower().endswith(".zip") or raw[:2] == b"PK":
            report = await import_archive(services.store, raw, passkey)
        else:
            report = await import_mafiles(
                services.store, [(filename, raw)], passkey
            )
    except ValueError as exc:
        await message.answer(html.quote(str(exc)))
        return
    except Exception as exc:  # noqa: BLE001
        log.exception("Import failed")
        await message.answer(f"Import failed: {html.quote(str(exc))}")
        return

    await state.update_data(
        imported=int(data.get("imported") or 0) + len(report.imported)
    )
    await message.answer(_import_summary(report, passkey))


def _import_summary(report, passkey: str | None) -> str:
    lines: list[str] = []

    if report.imported:
        lines.append(f"<b>Imported {len(report.imported)}:</b>")
        # Long imports would blow past Telegram's message limit, so the list
        # is capped and the remainder counted.
        for outcome in report.imported[:20]:
            lines.append(f"• {html.quote(outcome.account_name or '?')}")
        if len(report.imported) > 20:
            lines.append(f"• …and {len(report.imported) - 20} more")

    if report.failed:
        if lines:
            lines.append("")
        lines.append(f"<b>Skipped {len(report.failed)}:</b>")
        for outcome in report.failed[:20]:
            lines.append(
                f"• {html.quote(outcome.filename)} — "
                f"{html.quote(outcome.error or 'unknown')}"
            )
        if len(report.failed) > 20:
            lines.append(f"• …and {len(report.failed) - 20} more")

    if report.needed_passkey and not passkey:
        lines.append("")
        lines.append(
            "Some files are encrypted. Send <code>/import your-passkey</code> "
            "and upload the zip again — the archive's manifest.json holds the "
            "salt and IV needed to decrypt them."
        )

    if not lines:
        return "Nothing usable in that file."

    lines.append("")
    lines.append("Send more, or /done when finished.")
    return "\n".join(lines)


# ── Re-login ─────────────────────────────────────────────────────────────
#
# A stored session eventually expires and no refresh token can save it — Steam
# wants the password again. Only the password is asked for: the username comes
# from the maFile and the Steam Guard code is generated from the stored shared
# secret, so this is one message instead of three.


@router.callback_query(AccountCB.filter(F.action == "relogin"))
async def begin_relogin(
    query: CallbackQuery,
    callback_data: AccountCB,
    state: FSMContext,
    services: Services,
) -> None:
    account = services.store.get(callback_data.steam_id)
    if account is None:
        await query.answer("That account is gone.", show_alert=True)
        return

    if not account.account_name:
        await query.answer(
            "This account has no stored username — use /login instead.",
            show_alert=True,
        )
        return

    await state.set_state(Relogin.waiting_password)
    await state.update_data(steam_id=account.steam_id)
    await query.answer()

    await query.message.answer(
        f"Password for {html.bold(html.quote(account.account_name))}?\n\n"
        "I delete your message as soon as I read it, so it does not sit in "
        "the chat history."
        + (
            "\n\nThe Steam Guard code is generated here — you will not be "
            "asked for one."
            if account.shared_secret
            else ""
        )
        + "\n\n/cancel to abort."
    )


@router.message(Relogin.waiting_password, F.text)
async def got_relogin_password(
    message: Message, state: FSMContext, services: Services
) -> None:
    data = await state.get_data()
    account = services.store.get(int(data.get("steam_id") or 0))
    password = message.text or ""

    # Removed before anything else: Telegram keeps history, and a password
    # sitting in it is worse than any error below.
    with contextlib.suppress(Exception):
        await message.delete()

    if account is None or not account.account_name:
        await state.clear()
        await message.answer("That account is gone.")
        return

    notice = await message.answer(
        f"Signing in as {html.bold(html.quote(account.account_name))}…"
    )

    try:
        session = await services.auth.begin_with_credentials(
            account.account_name, password
        )
    except SteamAuthError as exc:
        await state.clear()
        await notice.edit_text(html.quote(str(exc)))
        return
    except Exception as exc:  # noqa: BLE001
        log.exception("Re-login failed")
        await state.clear()
        await notice.edit_text(f"Login failed: {html.quote(str(exc))}")
        return

    # The whole point of holding the maFile: answer Steam's own 2FA challenge
    # without bothering the admin for a code.
    if GUARD_TYPE_DEVICE_CODE in session.allowed_confirmations:
        if not account.shared_secret:
            await state.clear()
            await notice.edit_text(
                "Steam wants an authenticator code, but this account has no "
                "shared secret. Import its .maFile first."
            )
            return

        try:
            timestamp = await services.clock.current()
            await services.auth.submit_guard_code(
                session, generate_code(account.shared_secret, timestamp),
                GUARD_TYPE_DEVICE_CODE,
            )
        except Exception as exc:  # noqa: BLE001
            log.exception("Auto guard code failed")
            await state.clear()
            await notice.edit_text(f"Failed: {html.quote(str(exc))}")
            return

    elif GUARD_TYPE_EMAIL_CODE in session.allowed_confirmations:
        await state.update_data(auth=_dump(session))
        await state.set_state(Relogin.waiting_email_code)
        await notice.edit_text("Steam emailed you a code. What is it?")
        return

    await _finish_relogin(notice, state, services, session, account.steam_id)


@router.message(Relogin.waiting_email_code, F.text)
async def got_relogin_email_code(
    message: Message, state: FSMContext, services: Services
) -> None:
    data = await state.get_data()
    session = _load(data["auth"])
    steam_id = int(data.get("steam_id") or 0)

    notice = await message.answer("Submitting code…")

    try:
        await services.auth.submit_guard_code(
            session, (message.text or "").strip(), GUARD_TYPE_EMAIL_CODE
        )
    except Exception as exc:  # noqa: BLE001
        log.exception("Email code submission failed")
        await state.clear()
        await notice.edit_text(f"Failed: {html.quote(str(exc))}")
        return

    await _finish_relogin(notice, state, services, session, steam_id)


async def _finish_relogin(
    notice: Message,
    state: FSMContext,
    services: Services,
    session: AuthSession,
    expected_steam_id: int,
) -> None:
    """Poll for tokens, then replace the account's session with them."""
    for _ in range(20):
        try:
            payload = await services.auth.poll(session)
        except Exception:  # noqa: BLE001 - transient while pending
            payload = {}

        if payload.get("access_token"):
            # Derived from the token rather than assumed, so signing in as the
            # wrong account cannot overwrite this one's session.
            actual = SessionData.steam_id_from_token(
                str(payload.get("refresh_token") or payload["access_token"])
            )
            if actual and expected_steam_id and actual != expected_steam_id:
                await state.clear()
                await notice.edit_text(
                    f"Those credentials signed in "
                    f"{html.code(str(actual))}, not "
                    f"{html.code(str(expected_steam_id))}. Nothing was changed."
                )
                return

            try:
                account, _ = await services.store_login(payload, expected_steam_id)
            except SteamAuthError as exc:
                await state.clear()
                await notice.edit_text(html.quote(str(exc)))
                return

            await state.clear()
            await notice.edit_text(
                f"{html.bold(html.quote(account.display_name))} signed in "
                "again — session refreshed."
            )
            return

        await asyncio.sleep(session.interval)

    await state.clear()
    await notice.edit_text(
        "Timed out waiting for Steam. If it asked you to approve the login on "
        "another device, do that and try again."
    )


def _dump(session: AuthSession) -> dict:
    """FSM storage holds plain data, so the auth session is flattened."""
    return {
        "client_id": session.client_id,
        "request_id": session.request_id,
        "steam_id": session.steam_id,
        "interval": session.interval,
    }


def _load(data: dict) -> AuthSession:
    return AuthSession(
        client_id=data["client_id"],
        request_id=data["request_id"],
        steam_id=data.get("steam_id"),
        interval=int(data.get("interval") or 5),
    )
