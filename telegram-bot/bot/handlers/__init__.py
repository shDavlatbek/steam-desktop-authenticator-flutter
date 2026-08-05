"""Handler routers, registered in priority order."""

from __future__ import annotations

from aiogram import Router

from . import admin, admin_login, common, guest, sharing


def build_router() -> Router:
    """Compose every router.

    Order matters: `common` handles shared commands, the admin routers are
    gated by IsAdmin, and `guest` comes last so it only sees updates the admin
    routers did not claim.
    """
    root = Router(name="root")
    root.include_router(common.router)
    root.include_router(admin.router)
    root.include_router(admin_login.router)
    root.include_router(sharing.router)
    root.include_router(guest.router)
    return root


__all__ = ["build_router"]
