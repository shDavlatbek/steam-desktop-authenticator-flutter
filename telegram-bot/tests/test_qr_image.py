"""Decoding QR codes out of images a user sent.

Codes are generated with OpenCV's encoder so no extra dependency is needed.
The point of these is the preprocessing pipeline around the detector —
scaling, thresholding, inversion — which is what makes real screenshots and
Telegram-compressed photos decode.
"""

from __future__ import annotations

import cv2
import numpy as np
import pytest

from steamguard import QrChallenge
from steamguard.qr_image import decode_qr

CHALLENGE_URL = "https://s.team/q/1/2207813151333862682"


def render_qr(
    data: str = CHALLENGE_URL,
    *,
    scale: int = 8,
    quiet_zone: int = 4,
    inverted: bool = False,
    encode_as: str = ".png",
    jpeg_quality: int = 95,
) -> bytes:
    """Render ``data`` as a QR image, the way a screenshot would look."""
    matrix = cv2.QRCodeEncoder.create().encode(data)

    # The encoder returns the bare modules; a quiet zone is required for
    # detection and real renderers always include one.
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
        interpolation=cv2.INTER_NEAREST,
    )

    if inverted:
        enlarged = cv2.bitwise_not(enlarged)

    params = (
        [int(cv2.IMWRITE_JPEG_QUALITY), jpeg_quality]
        if encode_as in {".jpg", ".jpeg"}
        else []
    )
    ok, buffer = cv2.imencode(encode_as, enlarged, params)
    assert ok, "failed to encode the test image"
    return buffer.tobytes()


class TestDecodeQr:
    def test_reads_a_clean_screenshot(self):
        assert decode_qr(render_qr()) == CHALLENGE_URL

    def test_reads_a_jpeg_like_telegram_produces(self):
        assert decode_qr(render_qr(encode_as=".jpg", jpeg_quality=70)) == (
            CHALLENGE_URL
        )

    def test_reads_an_inverted_dark_theme_screenshot(self):
        # Exercises the bitwise_not variant; without it this returns None.
        assert decode_qr(render_qr(inverted=True)) == CHALLENGE_URL

    def test_reads_a_small_code(self):
        assert decode_qr(render_qr(scale=3)) == CHALLENGE_URL

    def test_reads_a_large_image_via_the_downscale_path(self):
        # Over the 4MP ceiling, so it goes through the resize branch.
        oversized = render_qr(scale=64)
        assert decode_qr(oversized) == CHALLENGE_URL

    def test_result_feeds_straight_into_the_challenge_parser(self):
        challenge = QrChallenge.try_parse(decode_qr(render_qr()))

        assert challenge is not None
        assert challenge.version == 1
        assert challenge.client_id == "2207813151333862682"

    def test_decodes_a_non_steam_payload_unchanged(self):
        """Decoding and validation stay separate concerns."""
        assert decode_qr(render_qr("https://example.com/hello")) == (
            "https://example.com/hello"
        )

    def test_returns_none_for_an_image_with_no_code(self):
        blank = np.full((300, 300), 255, dtype=np.uint8)
        ok, buffer = cv2.imencode(".png", blank)
        assert ok

        assert decode_qr(buffer.tobytes()) is None

    @pytest.mark.parametrize(
        "payload", [b"", b"this is not an image", bytes(range(256))]
    )
    def test_returns_none_for_non_images(self, payload):
        assert decode_qr(payload) is None
