"""Runtime configuration, read from the environment."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


@dataclass(frozen=True)
class Config:
    bot_token: str
    admin_id: int
    data_dir: Path
    passkey: str | None
    qr_request_ttl: int

    @classmethod
    def from_env(cls) -> "Config":
        load_dotenv()

        token = os.getenv("BOT_TOKEN", "").strip()
        if not token:
            raise SystemExit("BOT_TOKEN is not set. Copy .env.example to .env.")

        raw_admin = os.getenv("ADMIN_ID", "").strip()
        if not raw_admin.isdigit():
            raise SystemExit(
                "ADMIN_ID must be your numeric Telegram user ID. Ask @userinfobot."
            )

        # An empty passkey means "store unencrypted", matching the desktop app.
        passkey = os.getenv("SDA_PASSKEY", "").strip() or None

        return cls(
            bot_token=token,
            admin_id=int(raw_admin),
            data_dir=Path(os.getenv("DATA_DIR", "./data")).expanduser().resolve(),
            passkey=passkey,
            qr_request_ttl=int(os.getenv("QR_REQUEST_TTL", "180")),
        )
