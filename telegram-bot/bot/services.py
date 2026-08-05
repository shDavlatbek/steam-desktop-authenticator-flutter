"""The wired-up objects every handler shares.

Built once at startup and injected through the dispatcher's workflow data, so
handlers receive them as plain keyword arguments.
"""

from __future__ import annotations

import logging

from steamguard import (
    AccountStore,
    Confirmations,
    LoginApproval,
    SteamAuth,
    SteamGuardAccount,
    SteamTime,
    SteamWeb,
)

from .access import ShareRegistry
from .config import Config
from .pending import PendingQrRequests

log = logging.getLogger(__name__)


class Services:
    def __init__(self, config: Config) -> None:
        self.config = config

        self.web = SteamWeb()
        self.clock = SteamTime(self.web)
        self.auth = SteamAuth(self.web)
        self.approval = LoginApproval(self.web)
        self.confirmations = Confirmations(self.web, self.auth, self.clock)

        self.store = AccountStore(config.data_dir, config.passkey)
        self.shares = ShareRegistry(config.data_dir)
        self.pending_qr = PendingQrRequests(ttl_seconds=config.qr_request_ttl)

    async def start(self) -> None:
        await self.store.load()
        self.shares.load()

        if not self.config.passkey:
            log.warning(
                "SDA_PASSKEY is not set — shared secrets are stored in "
                "plaintext under %s",
                self.config.data_dir,
            )

    async def stop(self) -> None:
        await self.web.close()

    async def store_login(
        self, payload: dict, steam_id: int | None = None
    ) -> tuple[SteamGuardAccount, bool]:
        """Save the tokens from a successful login.

        Shared by password and QR sign-in so both behave identically: an
        existing account keeps its secrets and only has its session replaced,
        which is what makes this double as "log in again".

        Returns the account and whether it was newly created.
        """
        session = self.auth.session_from_tokens(payload, steam_id)

        existing = self.store.get(session.steam_id)
        account = existing or SteamGuardAccount()
        account.session = session

        name = payload.get("account_name")
        if name:
            account.account_name = str(name)
        elif not account.account_name:
            account.account_name = str(session.steam_id)

        await self.store.save_account(account)
        return account, existing is None

    async def persist(self, account) -> None:
        """Save an account after its tokens were refreshed in place.

        Without this a refreshed access token lives only in memory and the next
        restart pays for another refresh — or hits an expired token.
        """
        try:
            await self.store.save_account(account)
        except Exception:  # noqa: BLE001 - persistence must never break a flow
            log.exception("Could not persist account %s", account.steam_id)
