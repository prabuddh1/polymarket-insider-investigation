from typing import Any, Self

import httpx
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from src.common.config import settings


class ApiClient:
    def __init__(self, base_url: str) -> None:
        self.client = httpx.Client(
            base_url=base_url.rstrip("/"),
            timeout=settings.http_timeout_seconds,
            follow_redirects=True,
            headers={
                "Accept": "application/json",
                "User-Agent": "polymarket-insider-investigation/1.0",
            },
        )

    @retry(
        retry=retry_if_exception_type(
            (
                httpx.TimeoutException,
                httpx.TransportError,
                httpx.HTTPStatusError,
            )
        ),
        stop=stop_after_attempt(settings.http_max_retries),
        wait=wait_exponential(multiplier=1, min=1, max=30),
        reraise=True,
    )
    def get(
        self,
        path: str,
        params: dict[str, Any] | None = None,
    ) -> Any:
        response = self.client.get(path, params=params)
        response.raise_for_status()
        return response.json()

    def close(self) -> None:
        self.client.close()

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()
