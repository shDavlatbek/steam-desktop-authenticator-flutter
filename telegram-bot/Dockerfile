# syntax=docker/dockerfile:1

# aiogram 3.30 requires >=3.10,<3.15.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DATA_DIR=/data \
    # The container runs read-only; anything wanting a home gets tmpfs.
    HOME=/tmp

# libglib2.0-0: opencv-python-headless still links against libgthread even
#   though it draws nothing — without it, `import cv2` fails at runtime.
# tzdata: so a non-UTC TZ in compose resolves instead of silently staying UTC.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libglib2.0-0 tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencies first so code edits do not invalidate the install layer.
# Runtime requirements only — pytest has no business in a production image.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY steamguard/ ./steamguard/
COPY bot/ ./bot/

# A fixed UID so a bind-mounted data directory can be chowned to match.
RUN useradd --system --uid 10001 --create-home --home-dir /home/sda sda \
    && mkdir -p /data \
    && chown -R sda:sda /data /app

USER sda

# Polling only — the bot opens no listening port.
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD ["python", "-m", "bot.healthcheck"]

CMD ["python", "-m", "bot"]
