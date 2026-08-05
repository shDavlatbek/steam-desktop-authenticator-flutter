"""HTTP plumbing for Steam's APIs."""

from __future__ import annotations

import logging
from dataclasses import dataclass

import aiohttp

from .constants import MOBILE_APP_USER_AGENT, eresult_description

log = logging.getLogger(__name__)


@dataclass
class SteamResponse:
    """A response that carries Steam's `x-eresult` alongside the body.

    Several IAuthenticationService methods have an empty protobuf response, so
    success looks like `{"response":{}}` and failure like an empty body — the
    outcome is only legible from the header.
    """

    status: int
    body: str
    eresult: int | None = None
    error_message: str | None = None

    @property
    def ok(self) -> bool:
        if self.eresult is not None:
            return self.eresult == 1
        return self.status == 200 and bool(self.body.strip())

    @property
    def failure_reason(self) -> str:
        if self.error_message:
            return self.error_message
        if self.eresult is not None:
            return eresult_description(self.eresult)
        return f"Steam returned HTTP {self.status}."


class SteamWeb:
    """A shared aiohttp session presenting itself as the Steam mobile app."""

    def __init__(self, timeout_seconds: int = 30) -> None:
        self._timeout = aiohttp.ClientTimeout(total=timeout_seconds)
        self._session: aiohttp.ClientSession | None = None

    async def _ensure_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(timeout=self._timeout)
        return self._session

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()

    @staticmethod
    def _headers(cookies: dict[str, str] | None, form: bool) -> dict[str, str]:
        headers = {"User-Agent": MOBILE_APP_USER_AGENT}
        if form:
            headers["Content-Type"] = (
                "application/x-www-form-urlencoded; charset=UTF-8"
            )
        if cookies:
            headers["Cookie"] = "; ".join(f"{k}={v}" for k, v in cookies.items())
        return headers

    async def get(self, url: str, cookies: dict[str, str] | None = None) -> str:
        session = await self._ensure_session()
        log.debug("GET %s", url)
        async with session.get(url, headers=self._headers(cookies, False)) as resp:
            return await resp.text()

    async def post(
        self,
        url: str,
        data: dict[str, str] | None = None,
        cookies: dict[str, str] | None = None,
    ) -> str:
        session = await self._ensure_session()
        log.debug("POST %s", url)
        async with session.post(
            url, headers=self._headers(cookies, True), data=data or {}
        ) as resp:
            return await resp.text()

    async def post_raw(
        self,
        url: str,
        body: str,
        cookies: dict[str, str] | None = None,
    ) -> str:
        """POST a pre-encoded body.

        Needed for multiajaxop, which takes repeated cid[]/ck[] keys that a
        plain dict cannot express.
        """
        session = await self._ensure_session()
        log.debug("POST (raw) %s", url)
        async with session.post(
            url, headers=self._headers(cookies, True), data=body.encode("utf-8")
        ) as resp:
            return await resp.text()

    async def post_for_response(
        self,
        url: str,
        data: dict[str, str] | None = None,
        cookies: dict[str, str] | None = None,
    ) -> SteamResponse:
        session = await self._ensure_session()
        log.debug("POST %s (with eresult)", url)
        async with session.post(
            url, headers=self._headers(cookies, True), data=data or {}
        ) as resp:
            body = await resp.text()
            eresult = resp.headers.get("x-eresult")
            return SteamResponse(
                status=resp.status,
                body=body,
                eresult=int(eresult) if eresult and eresult.isdigit() else None,
                error_message=resp.headers.get("x-error_message"),
            )
