"""Rendering a challenge as a QR code.

The real assurance is the round trip: what the bot draws must be readable by
the same decoder that handles what users send it.
"""

from __future__ import annotations

import cv2
import numpy as np
import pytest

from steamguard import QrChallenge, QrRenderError, render_qr_png
from steamguard.qr_image import decode_qr

CHALLENGE_URL = "https://s.team/q/1/13180656742142139789"


def as_image(png: bytes):
    return cv2.imdecode(np.frombuffer(png, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)


class TestRenderQrPng:
    def test_produces_a_decodable_png(self):
        assert decode_qr(render_qr_png(CHALLENGE_URL)) == CHALLENGE_URL

    def test_round_trips_through_the_challenge_parser(self):
        challenge = QrChallenge.try_parse(decode_qr(render_qr_png(CHALLENGE_URL)))

        assert challenge is not None
        # A real client_id above int64's range, as Steam actually returns.
        assert challenge.client_id == "13180656742142139789"

    def test_output_is_a_png(self):
        assert render_qr_png(CHALLENGE_URL)[:8] == b"\x89PNG\r\n\x1a\n"

    def test_includes_a_quiet_zone(self):
        """Without the margin, detectors cannot find the finder patterns."""
        image = as_image(render_qr_png(CHALLENGE_URL, scale=4, quiet_zone=4))

        # Every corner pixel should be white background.
        assert image[0, 0] == 255
        assert image[-1, -1] == 255
        assert image[0, -1] == 255

    def test_scale_changes_the_pixel_size(self):
        small = as_image(render_qr_png(CHALLENGE_URL, scale=4))
        large = as_image(render_qr_png(CHALLENGE_URL, scale=8))

        assert large.shape[0] == small.shape[0] * 2

    def test_stays_crisp_black_and_white(self):
        """Nearest-neighbour scaling must not introduce grey edges."""
        image = as_image(render_qr_png(CHALLENGE_URL, scale=6))

        assert set(np.unique(image)).issubset({0, 255})

    def test_inverted_output_still_decodes(self):
        assert decode_qr(render_qr_png(CHALLENGE_URL, inverted=True)) == (
            CHALLENGE_URL
        )

    def test_rejects_empty_input(self):
        with pytest.raises(QrRenderError):
            render_qr_png("")

    @pytest.mark.parametrize("scale", [1, 2])
    def test_refuses_a_scale_too_small_to_scan(self, scale):
        """One pixel per module renders something that looks like a QR code
        and cannot be read. Better to fail than to ship that."""
        with pytest.raises(QrRenderError, match="scannable"):
            render_qr_png(CHALLENGE_URL, scale=scale)

    def test_refuses_to_drop_the_quiet_zone(self):
        with pytest.raises(QrRenderError, match="quiet zone"):
            render_qr_png(CHALLENGE_URL, quiet_zone=0)

    @pytest.mark.parametrize("scale", [3, 4, 10, 20])
    def test_every_permitted_scale_decodes(self, scale):
        assert decode_qr(render_qr_png(CHALLENGE_URL, scale=scale)) == (
            CHALLENGE_URL
        )
