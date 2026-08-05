"""Rendering a Steam challenge URL as a QR image.

Uses OpenCV's encoder, which is already a dependency for decoding — so showing
a QR costs no extra package.
"""

from __future__ import annotations

import cv2

# Steam's challenge URLs are short, so the generated matrix is small (~33
# modules). It has to be scaled up and given a quiet zone before any phone
# camera will look at it.
DEFAULT_SCALE = 10
DEFAULT_QUIET_ZONE = 4

# Below roughly three pixels per module, finder patterns stop being reliably
# detectable — the image looks like a QR code but nothing can read it. Refused
# outright rather than silently emitting something unscannable.
MIN_SCALE = 3


class QrRenderError(Exception):
    """The payload could not be encoded as a QR code."""


def render_qr_png(
    data: str,
    *,
    scale: int = DEFAULT_SCALE,
    quiet_zone: int = DEFAULT_QUIET_ZONE,
    inverted: bool = False,
) -> bytes:
    """Return a PNG of ``data`` encoded as a QR code.

    Rendered dark-on-white regardless of anyone's theme — inverted codes are
    unreliable with some phone cameras.
    """
    if not data:
        raise QrRenderError("Nothing to encode")
    if scale < MIN_SCALE:
        raise QrRenderError(
            f"scale {scale} is too small to be scannable; minimum is {MIN_SCALE}"
        )
    if quiet_zone < 1:
        raise QrRenderError("a quiet zone of at least 1 module is required")

    try:
        matrix = cv2.QRCodeEncoder.create().encode(data)
    except cv2.error as exc:
        raise QrRenderError(f"Could not encode QR code: {exc}") from exc

    if matrix is None or matrix.size == 0:
        raise QrRenderError("Encoder produced an empty image")

    # A quiet zone is part of the spec, not decoration — detectors need the
    # clear margin to find the finder patterns.
    padded = cv2.copyMakeBorder(
        matrix,
        quiet_zone,
        quiet_zone,
        quiet_zone,
        quiet_zone,
        cv2.BORDER_CONSTANT,
        value=255,
    )

    enlarged = cv2.resize(
        padded,
        (padded.shape[1] * scale, padded.shape[0] * scale),
        # Nearest neighbour keeps module edges crisp; interpolation would
        # blur them into grey and hurt detection.
        interpolation=cv2.INTER_NEAREST,
    )

    if inverted:
        enlarged = cv2.bitwise_not(enlarged)

    ok, buffer = cv2.imencode(".png", enlarged)
    if not ok:
        raise QrRenderError("Could not encode the QR image as PNG")

    return buffer.tobytes()
