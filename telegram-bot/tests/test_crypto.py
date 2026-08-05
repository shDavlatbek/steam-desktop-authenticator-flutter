"""Behavioural tests for the crypto primitives.

`test_dart_parity.py` pins the exact bytes; these cover the edges around them.
"""

from __future__ import annotations

import base64

import pytest

from steamguard import file_encryptor, mobile_signature
from steamguard.qr_challenge import QrChallenge
from steamguard.totp import generate_code, seconds_remaining

SECRET = base64.b64encode(bytes(range(1, 21))).decode()


class TestTotp:
    def test_returns_five_characters_from_the_steam_alphabet(self):
        code = generate_code(SECRET, 1700000000)
        assert len(code) == 5
        assert set(code) <= set("23456789BCDFGHJKMNPQRTVWXY")

    def test_is_stable_within_a_30_second_window(self):
        # Aligned to a window start: 1700000000 itself sits 20s into one, so
        # +29 would land in the next window.
        start = 1700000000 - (1700000000 % 30)
        assert generate_code(SECRET, start) == generate_code(SECRET, start + 29)

    def test_changes_at_the_window_boundary(self):
        start = 1700000000 - (1700000000 % 30)
        assert generate_code(SECRET, start) != generate_code(SECRET, start + 30)

    def test_unescapes_json_escaped_secrets(self):
        raw = base64.b64encode(bytes(range(60, 80))).decode()
        if "/" not in raw:
            pytest.skip("no slash to unescape in this fixture")
        assert generate_code(raw.replace("/", "\\/"), 1) == generate_code(raw, 1)

    @pytest.mark.parametrize("bad", [None, "", "not base64!!"])
    def test_returns_empty_for_unusable_secrets(self, bad):
        assert generate_code(bad, 1700000000) == ""

    def test_seconds_remaining_counts_down_to_the_boundary(self):
        assert seconds_remaining(1700000000) == 30 - (1700000000 % 30)


class TestMobileSignature:
    def test_produces_32_bytes(self):
        assert (
            len(mobile_signature.generate(SECRET, 1, "123", "456")) == 32
        )

    def test_each_field_changes_the_signature(self):
        base = mobile_signature.generate(SECRET, 1, "123", "456")
        assert mobile_signature.generate(SECRET, 2, "123", "456") != base
        assert mobile_signature.generate(SECRET, 1, "124", "456") != base
        assert mobile_signature.generate(SECRET, 1, "123", "457") != base

    def test_accepts_full_width_uint64(self):
        largest = "18446744073709551615"
        assert len(mobile_signature.generate(SECRET, 0xFFFF, largest, largest)) == 32

    @pytest.mark.parametrize(
        "version,client_id",
        [
            (0x10000, "1"),  # wider than uint16
            (1, "-1"),
            (1, "18446744073709551616"),  # 2^64
            (1, "not-a-number"),
        ],
    )
    def test_rejects_out_of_range_input(self, version, client_id):
        with pytest.raises(ValueError):
            mobile_signature.generate(SECRET, version, client_id, "456")

    def test_rejects_missing_secret(self):
        with pytest.raises(ValueError):
            mobile_signature.generate("", 1, "1", "1")


class TestFileEncryptor:
    def test_round_trips(self):
        salt = file_encryptor.get_random_salt()
        iv = file_encryptor.get_initialization_vector()

        blob = file_encryptor.encrypt_data("pw", salt, iv, "secret payload")
        assert file_encryptor.decrypt_data("pw", salt, iv, blob) == "secret payload"

    def test_wrong_password_returns_none(self):
        salt = file_encryptor.get_random_salt()
        iv = file_encryptor.get_initialization_vector()

        blob = file_encryptor.encrypt_data("right", salt, iv, "payload")
        assert file_encryptor.decrypt_data("wrong", salt, iv, blob) is None

    def test_salts_and_ivs_are_random(self):
        assert file_encryptor.get_random_salt() != file_encryptor.get_random_salt()
        assert (
            file_encryptor.get_initialization_vector()
            != file_encryptor.get_initialization_vector()
        )

    def test_salt_and_iv_are_the_expected_widths(self):
        assert len(base64.b64decode(file_encryptor.get_random_salt())) == 8
        assert (
            len(base64.b64decode(file_encryptor.get_initialization_vector())) == 16
        )

    def test_handles_unicode_and_large_payloads(self):
        salt = file_encryptor.get_random_salt()
        iv = file_encryptor.get_initialization_vector()

        payload = "Ünïcödé 🎮 " * 5000
        blob = file_encryptor.encrypt_data("pw", salt, iv, payload)
        assert file_encryptor.decrypt_data("pw", salt, iv, blob) == payload

    @pytest.mark.parametrize(
        "password,salt,iv,text",
        [
            ("", "AQIDBAUGBwg=", "AQIDBAUGBwgJCgsMDQ4PEA==", "x"),
            ("pw", "", "AQIDBAUGBwgJCgsMDQ4PEA==", "x"),
            ("pw", "AQIDBAUGBwg=", "", "x"),
            ("pw", "AQIDBAUGBwg=", "AQIDBAUGBwgJCgsMDQ4PEA==", ""),
        ],
    )
    def test_rejects_empty_arguments(self, password, salt, iv, text):
        with pytest.raises(ValueError):
            file_encryptor.encrypt_data(password, salt, iv, text)


class TestQrChallenge:
    def test_parses_a_live_challenge_url(self):
        challenge = QrChallenge.try_parse("https://s.team/q/1/2207813151333862682")
        assert challenge == QrChallenge(version=1, client_id="2207813151333862682")

    def test_keeps_the_client_id_exact(self):
        largest = "18446744073709551615"
        assert QrChallenge.try_parse(f"https://s.team/q/1/{largest}").client_id == (
            largest
        )

    def test_accepts_http_and_a_query_string(self):
        assert QrChallenge.try_parse("http://s.team/q/1/123").client_id == "123"
        assert QrChallenge.try_parse("https://s.team/q/2/456?t=x").version == 2

    def test_strips_surrounding_whitespace(self):
        assert QrChallenge.try_parse("  https://s.team/q/1/123\n").client_id == "123"

    @pytest.mark.parametrize(
        "url",
        [
            None,
            "",
            "https://example.com/q/1/123",
            "https://s.team/q/1",
            "https://s.team/q/abc/123",
            "https://s.team.evil.com/q/1/123",
            "otpauth://totp/Steam:username",
        ],
    )
    def test_rejects_anything_else(self, url):
        assert QrChallenge.try_parse(url) is None
