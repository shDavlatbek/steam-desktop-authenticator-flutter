"""maFile encryption, compatible with the desktop app and the original C# SDA.

    PBKDF2 (SHA1, 50000 iterations, 8-byte salt) -> 32-byte key
    AES-256-CBC (PKCS7 padding, 16-byte IV)

Salt and IV live in manifest.json per entry; the ciphertext is base64 inside
the .maFile. A file encrypted here decrypts in the Flutter app and vice versa —
`tests/test_file_encryptor.py` pins that with a fixture produced by the Dart
implementation.
"""

from __future__ import annotations

import base64
import os

from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

PBKDF2_ITERATIONS = 50_000
SALT_LENGTH = 8
KEY_SIZE_BYTES = 32
IV_LENGTH = 16
_AES_BLOCK_BITS = 128


def get_random_salt() -> str:
    """A fresh 8-byte salt, base64-encoded."""
    return base64.b64encode(os.urandom(SALT_LENGTH)).decode("ascii")


def get_initialization_vector() -> str:
    """A fresh 16-byte IV, base64-encoded."""
    return base64.b64encode(os.urandom(IV_LENGTH)).decode("ascii")


def encrypt_data(password: str, salt: str, iv: str, plaintext: str) -> str:
    """Encrypt ``plaintext``, returning base64 ciphertext."""
    if not plaintext:
        raise ValueError("Plaintext data is empty")

    key = _derive_key(password, salt)
    iv_bytes = base64.b64decode(_require(iv, "Initialization Vector"))

    padder = padding.PKCS7(_AES_BLOCK_BITS).padder()
    padded = padder.update(plaintext.encode("utf-8")) + padder.finalize()

    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv_bytes)).encryptor()
    ciphertext = encryptor.update(padded) + encryptor.finalize()

    return base64.b64encode(ciphertext).decode("ascii")


def decrypt_data(password: str, salt: str, iv: str, encrypted: str) -> str | None:
    """Decrypt base64 ciphertext, or return None if the password is wrong.

    A wrong password derives a wrong key, which surfaces as a padding or UTF-8
    failure rather than anything more specific — so both are treated as
    "bad passkey", matching the desktop app.
    """
    if not encrypted:
        raise ValueError("Encrypted data is empty")

    key = _derive_key(password, salt)
    iv_bytes = base64.b64decode(_require(iv, "Initialization Vector"))

    try:
        ciphertext = base64.b64decode(encrypted)
        decryptor = Cipher(algorithms.AES(key), modes.CBC(iv_bytes)).decryptor()
        padded = decryptor.update(ciphertext) + decryptor.finalize()

        unpadder = padding.PKCS7(_AES_BLOCK_BITS).unpadder()
        plaintext = unpadder.update(padded) + unpadder.finalize()
        return plaintext.decode("utf-8")
    except Exception:
        return None


def _derive_key(password: str, salt: str) -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA1(),
        length=KEY_SIZE_BYTES,
        salt=base64.b64decode(_require(salt, "Salt")),
        iterations=PBKDF2_ITERATIONS,
    )
    return kdf.derive(_require(password, "Password").encode("utf-8"))


def _require(value: str, name: str) -> str:
    if not value:
        raise ValueError(f"{name} is empty")
    return value
