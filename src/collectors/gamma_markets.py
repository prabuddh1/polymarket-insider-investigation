import argparse
import json
import random
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx
from sqlalchemy import text

from src.common.config import settings
from src.common.db import engine
from src.common.files import write_json

PAGE_SIZE = 100
REQUEST_DELAY_SECONDS = 0.35
CHECKPOINT_FILE = Path("data/processed/gamma_markets_checkpoint.json")


MARKET_UPSERT = text(
    """
    INSERT INTO raw_markets (
        market_id,
        condition_id,
        payload,
        collected_at
    )
    VALUES (
        :market_id,
        :condition_id,
        CAST(:payload AS JSONB),
        NOW()
    )
    ON CONFLICT (market_id)
    DO UPDATE SET
        condition_id = EXCLUDED.condition_id,
        payload = EXCLUDED.payload,
        collected_at = NOW()
    """
)


def upsert_markets(records: list[dict[str, Any]]) -> int:
    rows: list[dict[str, Any]] = []

    for record in records:
        market_id = record.get("id")

        if market_id is None:
            continue

        rows.append(
            {
                "market_id": str(market_id),
                "condition_id": record.get("conditionId"),
                "payload": json.dumps(record),
            }
        )

    if not rows:
        return 0

    with engine.begin() as connection:
        connection.execute(MARKET_UPSERT, rows)

    return len(rows)


def load_checkpoint() -> tuple[str | None, int]:
    if not CHECKPOINT_FILE.exists():
        return None, 0

    payload = json.loads(
        CHECKPOINT_FILE.read_text(encoding="utf-8")
    )

    return payload.get("after_cursor"), int(
        payload.get("next_page", 0)
    )


def save_checkpoint(
    after_cursor: str,
    next_page: int,
) -> None:
    CHECKPOINT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    CHECKPOINT_FILE.write_text(
        json.dumps(
            {
                "after_cursor": after_cursor,
                "next_page": next_page,
                "updated_at": datetime.now(UTC).isoformat(),
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def fetch_page(
    client: httpx.Client,
    after_cursor: str | None,
) -> dict[str, Any]:
    params: dict[str, Any] = {
        "closed": "true",
        "limit": PAGE_SIZE,
        "ascending": "true",
        "order": "endDate",
        "end_date_min": settings.analysis_start.isoformat(),
        "end_date_max": settings.analysis_end.isoformat(),
    }

    if after_cursor:
        params["after_cursor"] = after_cursor

    for attempt in range(1, 9):
        try:
            response = client.get(
                "/markets/keyset",
                params=params,
            )

            if response.status_code in {403, 429}:
                retry_after = response.headers.get("Retry-After")

                delay = (
                    float(retry_after)
                    if retry_after
                    else min(60 * attempt, 300)
                )

                print(
                    f"HTTP {response.status_code}; "
                    f"sleeping {delay:.0f}s "
                    f"before retry {attempt}/8",
                    flush=True,
                )
                time.sleep(delay)
                continue

            response.raise_for_status()
            payload = response.json()

            if not isinstance(payload, dict):
                raise TypeError(
                    "Expected an object response from Gamma"
                )

            return payload

        except httpx.TransportError as exc:
            if attempt == 8:
                raise

            delay = min(2**attempt, 60)

            print(
                f"Transport error: {exc}; "
                f"sleeping {delay}s",
                flush=True,
            )
            time.sleep(delay)

    raise RuntimeError("Gamma request exhausted all retries")


def collect_markets(
    max_pages: int | None,
    resume: bool,
) -> int:
    run_stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    raw_directory = (
        settings.raw_data_dir
        / "gamma"
        / f"markets_window_{run_stamp}"
    )
    raw_directory.mkdir(parents=True, exist_ok=True)

    if resume:
        after_cursor, page_number = load_checkpoint()
    else:
        after_cursor, page_number = None, 0

    total_stored = 0

    with httpx.Client(
        base_url=settings.gamma_api_base.rstrip("/"),
        timeout=60,
        follow_redirects=True,
        headers={
            "Accept": "application/json",
            "User-Agent": (
                "polymarket-insider-investigation/1.0 "
                "(research assessment)"
            ),
        },
    ) as client:
        while True:
            if (
                max_pages is not None
                and page_number >= max_pages
            ):
                print(
                    f"Stopped at max_pages={max_pages}",
                    flush=True,
                )
                break

            payload = fetch_page(
                client=client,
                after_cursor=after_cursor,
            )

            records = payload.get("markets", [])

            if not isinstance(records, list):
                raise TypeError(
                    "Expected 'markets' to be a list"
                )

            write_json(
                raw_directory / f"page_{page_number:05d}.json",
                payload,
            )

            stored = upsert_markets(records)
            total_stored += stored

            next_cursor = payload.get("next_cursor")

            print(
                f"page={page_number}, "
                f"received={len(records)}, "
                f"stored={stored}, "
                f"run_total={total_stored}, "
                f"has_next={bool(next_cursor)}",
                flush=True,
            )

            if not records or not next_cursor:
                CHECKPOINT_FILE.unlink(missing_ok=True)
                print("Market collection complete", flush=True)
                break

            if next_cursor == after_cursor:
                raise RuntimeError(
                    "Gamma returned the same cursor twice"
                )

            after_cursor = str(next_cursor)
            page_number += 1

            save_checkpoint(
                after_cursor=after_cursor,
                next_page=page_number,
            )

            time.sleep(
                REQUEST_DELAY_SECONDS
                + random.uniform(0.05, 0.25)
            )

    return total_stored


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Collect Polymarket markets within "
            "the assessment window."
        )
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=None,
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from the last successful cursor.",
    )
    parser.add_argument(
        "--reset-checkpoint",
        action="store_true",
    )
    args = parser.parse_args()

    if args.reset_checkpoint:
        CHECKPOINT_FILE.unlink(missing_ok=True)

    total = collect_markets(
        max_pages=args.max_pages,
        resume=args.resume,
    )

    print(
        f"Market rows processed in this run: {total}",
        flush=True,
    )


if __name__ == "__main__":
    main()
