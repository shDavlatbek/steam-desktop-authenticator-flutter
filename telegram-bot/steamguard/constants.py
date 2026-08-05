"""Steam constants and endpoints, mirroring the desktop app's copies."""

from __future__ import annotations

# The alphabet Steam Guard codes are drawn from. Ambiguous glyphs (0/O, 1/I/L,
# S/5, A/E/U) are deliberately absent.
CODE_ALPHABET = b"23456789BCDFGHJKMNPQRTVWXY"

TOTP_PERIOD = 30
TOTP_CODE_LENGTH = 5

MOBILE_APP_USER_AGENT = (
    "Dalvik/2.1.0 (Linux; U; Android 9; Valve Steam App Version/3)"
)
MOBILE_CLIENT = "android"
MOBILE_CLIENT_VERSION = "777777 3.6.4"

STEAM_API_BASE = "https://api.steampowered.com"
COMMUNITY_BASE = "https://steamcommunity.com"

# EAuthTokenPlatformType. MobileApp is what yields tokens carrying the "mobile"
# audience, which the confirmation endpoints require.
PLATFORM_TYPE_STEAM_CLIENT = 1
PLATFORM_TYPE_WEB_BROWSER = 2
PLATFORM_TYPE_MOBILE_APP = 3

# EAuthSessionGuardType
GUARD_TYPE_NONE = 1
GUARD_TYPE_EMAIL_CODE = 2
GUARD_TYPE_DEVICE_CODE = 3
GUARD_TYPE_DEVICE_CONFIRMATION = 4


class ApiEndpoints:
    TWO_FACTOR_TIME_QUERY = f"{STEAM_API_BASE}/ITwoFactorService/QueryTime/v0001"

    AUTH_GET_RSA_KEY = (
        f"{STEAM_API_BASE}/IAuthenticationService/GetPasswordRSAPublicKey/v1"
    )
    AUTH_BEGIN_VIA_CREDENTIALS = (
        f"{STEAM_API_BASE}/IAuthenticationService/BeginAuthSessionViaCredentials/v1"
    )
    AUTH_BEGIN_VIA_QR = (
        f"{STEAM_API_BASE}/IAuthenticationService/BeginAuthSessionViaQR/v1"
    )
    AUTH_POLL_SESSION = (
        f"{STEAM_API_BASE}/IAuthenticationService/PollAuthSessionStatus/v1"
    )
    AUTH_UPDATE_WITH_GUARD_CODE = (
        f"{STEAM_API_BASE}"
        "/IAuthenticationService/UpdateAuthSessionWithSteamGuardCode/v1"
    )
    AUTH_GENERATE_ACCESS_TOKEN = (
        f"{STEAM_API_BASE}/IAuthenticationService/GenerateAccessTokenForApp/v1/"
    )
    AUTH_GET_SESSION_INFO = (
        f"{STEAM_API_BASE}/IAuthenticationService/GetAuthSessionInfo/v1"
    )
    AUTH_UPDATE_WITH_MOBILE_CONFIRMATION = (
        f"{STEAM_API_BASE}"
        "/IAuthenticationService/UpdateAuthSessionWithMobileConfirmation/v1"
    )

    CONFIRMATION_GET_LIST = f"{COMMUNITY_BASE}/mobileconf/getlist"
    CONFIRMATION_AJAX_OP = f"{COMMUNITY_BASE}/mobileconf/ajaxop"
    CONFIRMATION_MULTI_AJAX_OP = f"{COMMUNITY_BASE}/mobileconf/multiajaxop"


def eresult_description(code: int) -> str:
    """Human-readable text for the EResult codes these flows produce."""
    return {
        1: "Success.",
        2: "Steam rejected the request.",
        5: "Invalid password or signature.",
        8: "Steam rejected one of the parameters.",
        15: "Access denied — the access token may lack mobile permissions.",
        16: "The request timed out.",
        21: "This login request has expired.",
        27: "This login request was already used.",
        84: "Rate limited by Steam. Wait a while and try again.",
    }.get(code, f"Steam returned error code {code}.")
