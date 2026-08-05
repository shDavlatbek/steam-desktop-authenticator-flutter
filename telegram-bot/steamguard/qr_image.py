"""Reading a QR code out of a photo or screenshot a user sent.

Uses OpenCV's built-in detector rather than pyzbar so there is no native zbar
library to install on the host — `opencv-python-headless` ships prebuilt wheels.

Telegram re-encodes photos as JPEG at reduced quality, so a single strict pass
is not enough in practice; several preprocessing variants are tried in
increasing order of cost.
"""

from __future__ import annotations

import cv2
import numpy as np

# Above this, images are downscaled before decoding. Phone photos are routinely
# 12MP, which is far more detail than a QR needs and slow to work through.
_MAX_PIXELS = 4_000_000


def decode_qr(image_bytes: bytes) -> str | None:
    """Return the QR payload found in ``image_bytes``, or None."""
    image = _load(image_bytes)
    if image is None:
        return None

    detector = cv2.QRCodeDetector()

    for candidate in _variants(image):
        for decode in (detector.detectAndDecode, detector.detectAndDecodeCurved):
            try:
                value = decode(candidate)[0]
            except cv2.error:
                continue
            if value:
                return value

    return None


def _load(image_bytes: bytes):
    if not image_bytes:
        return None

    try:
        buffer = np.frombuffer(image_bytes, dtype=np.uint8)
        image = cv2.imdecode(buffer, cv2.IMREAD_GRAYSCALE)
    except Exception:
        return None

    if image is None:
        return None

    height, width = image.shape[:2]
    pixels = width * height
    if pixels > _MAX_PIXELS:
        scale = (_MAX_PIXELS / pixels) ** 0.5
        image = cv2.resize(
            image,
            (max(1, int(width * scale)), max(1, int(height * scale))),
            interpolation=cv2.INTER_AREA,
        )

    return image


def _variants(image):
    """Progressively more aggressive renditions of the same image.

    Ordered cheapest-first so a clean screenshot decodes on the first pass.
    """
    # As-is: correct for a clean screenshot.
    yield image

    # Otsu threshold: recovers codes shot under uneven lighting.
    _, otsu = cv2.threshold(image, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    yield otsu

    # Inverted: a screenshot from a dark-themed page arrives light-on-dark, and
    # the detector expects dark modules on a light field.
    yield cv2.bitwise_not(otsu)

    # Upscaled: small or heavily compressed codes gain enough definition for
    # the finder patterns to register.
    height, width = image.shape[:2]
    if width * height * 4 <= _MAX_PIXELS * 4:
        yield cv2.resize(
            image, (width * 2, height * 2), interpolation=cv2.INTER_CUBIC
        )
