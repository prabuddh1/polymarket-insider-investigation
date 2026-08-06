import argparse
import hashlib
import json
import random
import time
from datetime import UTC, datetime
from typing import Any

import httpx
from sqlalchemy import text

from src.common.config import settings
from src.common.db import engine

PAGE_SIZE = 1000
MAX_OFFSET = 9000
MIN_WINDOW_SECONDS = 60
REQUEST_DELAY_SECONDS = 0.15
MAX_RETRIES = 8
MAX_RECURSION_DEPTH = 25

ANALYSIS_START_TS = int(
    settings.analysis_start.timestamp()
)
ANALYSIS_END_TS = int(
    settings.analysis_end.timestamp()
) - 1

DATA_API_BASE = getattr(
    settings,
    "data_api_base",
    "https://data-api.polymarket.com",
).rstrip("/")


RAW_TRADE_UPSERT = text(
    """
    INSERT INTO raw_trades (
        trade_key,
        transaction_hash,
        condition_id,
        proxy_wallet,
        traded_at,
        payload,
        collected_at
    )
    VALUES (
        :trade_key,
        :transaction_hash,
        :condition_id,
        :proxy_wallet,
        :traded_at,
        CAST(:payload AS JSONB),
        NOW()
    )
    ON CONFLICT (trade_key)
    DO UPDATE SET
        payload = EXCLUDED.payload,
        collected_at = NOW()
    """
)


MARK_RUNNING = text(
    """
    UPDATE trade_collection_progress
    SET
        status = 'running',
        attempts = attempts + 1,
        started_at = COALESCE(started_at, NOW()),
        last_error = NULL,
        updated_at = NOW()
    WHERE condition_id = :condition_id
    """
)


MARK_COMPLETE = text(
    """
    UPDATE trade_collection_progress
    SET
        status = 'completed',
        trades_stored = :trades_stored,
        windows_processed = :windows_processed,
        completed_at = NOW(),
        last_error = NULL,
        updated_at = NOW()
    WHERE condition_id = :condition_id
    """
)


MARK_FAILED = text(
    """
    UPDATE trade_collection_progress
    SET
        status = 'failed',
        last_error = :last_error,
        updated_at = NOW()
    WHERE condition_id = :condition_id
    """
)


def make_trade_key(trade: dict[str, Any]) -> str:
    parts = (
        str(trade.get("transactionHash") or ""),
        str(trade.get("conditionId") or ""),
        str(trade.get("proxyWallet") or "").lower(),
        str(trade.get("asset") or ""),
        str(trade.get("side") or ""),
        str(trade.get("size") or ""),
        str(trade.get("price") or ""),
        str(trade.get("timestamp") or ""),
    )

    canonical = "|".join(parts)

    return hashlib.sha256(
        canonical.encode("utf-8")
    ).hexdigest()


def upsert_trades(
    trades: list[dict[str, Any]],
) -> int:
    rows: list[dict[str, Any]] = []

    for trade in trades:
        condition_id = trade.get("conditionId")
        timestamp = trade.get("timestamp")

        if condition_id is None or timestamp is None:
            continue

        rows.append(
            {
                "trade_key": make_trade_key(trade),
                "transaction_hash": trade.get(
                    "transactionHash"
                ),
                "condition_id": str(condition_id),
                "proxy_wallet": str(
                    trade.get("proxyWallet") or ""
                ).lower(),
                "traded_at": datetime.fromtimestamp(
                    int(timestamp),
                    tz=UTC,
                ),
                "payload": json.dumps(trade),
            }
        )

    if not rows:
        return 0

    with engine.begin() as connection:
        connection.execute(RAW_TRADE_UPSERT, rows)

    return len(rows)


def fetch_page(
    client: httpx.Client,
    condition_id: str,
    start_ts: int,
    end_ts: int,
    offset: int,
) -> list[dict[str, Any]]:
    params = {
        "market": condition_id,
        "limit": PAGE_SIZE,
        "offset": offset,
        "takerOnly": "true",
        "start": start_ts,
        "end": end_ts,
    }

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = client.get(
                "/trades",
                params=params,
            )

            if response.status_code in {403, 429}:
                retry_after = response.headers.get(
                    "Retry-After"
                )

                delay = (
                    float(retry_after)
                    if retry_after
                    else min(30 * attempt, 240)
                )

                print(
                    f"HTTP {response.status_code}; "
                    f"sleeping {delay:.0f}s "
                    f"before retry {attempt}/"
                    f"{MAX_RETRIES}",
                    flush=True,
                )
                time.sleep(delay)
                continue

            response.raise_for_status()
            payload = response.json()

            if not isinstance(payload, list):
                raise TypeError(
                    "Data API trade response "
                    "was not a list"
                )

            return payload

        except (
            httpx.TransportError,
            httpx.HTTPStatusError,
            json.JSONDecodeError,
        ) as exc:
            if attempt == MAX_RETRIES:
                raise

            delay = min(2**attempt, 60)

            print(
                f"Request error: {exc}; "
                f"sleeping {delay}s",
                flush=True,
            )
            time.sleep(delay)

    raise RuntimeError(
        "Trade request exhausted all retries"
    )


def collect_window(
    client: httpx.Client,
    condition_id: str,
    start_ts: int,
    end_ts: int,
    depth: int = 0,
) -> tuple[int, int]:
    """
    Return:
        trades processed,
        terminal windows processed.
    """
    if start_ts > end_ts:
        return 0, 0

    if depth > MAX_RECURSION_DEPTH:
        raise RuntimeError(
            "Maximum trade-window recursion depth exceeded: "
            f"depth={depth}, window={start_ts}:{end_ts}"
        )

    total_stored = 0

    for offset in range(
        0,
        MAX_OFFSET + PAGE_SIZE,
        PAGE_SIZE,
    ):
        trades = fetch_page(
            client=client,
            condition_id=condition_id,
            start_ts=start_ts,
            end_ts=end_ts,
            offset=offset,
        )

        stored = upsert_trades(trades)
        total_stored += stored

        print(
            f"  depth={depth} "
            f"window={start_ts}:{end_ts} "
            f"offset={offset} "
            f"received={len(trades)} "
            f"stored={stored}",
            flush=True,
        )

        if len(trades) < PAGE_SIZE:
            return total_stored, 1

        if offset == MAX_OFFSET:
            duration = end_ts - start_ts

            if duration <= MIN_WINDOW_SECONDS:
                raise RuntimeError(
                    "More than 10,000 trades found "
                    "inside minimum time window "
                    f"{start_ts}:{end_ts}"
                )

            midpoint = start_ts + duration // 2

            print(
                f"  depth={depth} dense window; splitting "
                f"{start_ts}:{end_ts} at {midpoint}",
                flush=True,
            )

            left_trades, left_windows = collect_window(
                client=client,
                condition_id=condition_id,
                start_ts=start_ts,
                end_ts=midpoint,
                depth=depth + 1,
            )

            right_trades, right_windows = collect_window(
                client=client,
                condition_id=condition_id,
                start_ts=midpoint + 1,
                end_ts=end_ts,
                depth=depth + 1,
            )

            return (
                left_trades + right_trades,
                left_windows + right_windows,
            )

        time.sleep(
            REQUEST_DELAY_SECONDS
            + random.uniform(0.02, 0.12)
        )

    raise RuntimeError(
        "Unexpected pagination termination"
    )


def load_markets(
    limit_markets: int | None,
    market_id: str | None,
    include_failed: bool,
    worker_index: int,
    worker_count: int,
) -> list[dict[str, Any]]:
    filters = [
        (
            "EXISTS ("
            "SELECT 1 FROM investigation_markets im "
            "WHERE im.condition_id = m.condition_id"
            ")"
        ),
        "m.condition_id IS NOT NULL",
    ]

    params: dict[str, Any] = {
        "worker_index": worker_index,
        "worker_count": worker_count,
    }

    filters.append(
        "MOD(ABS(HASHTEXT(m.condition_id)), :worker_count) "
        "= :worker_index"
    )

    if market_id:
        filters.append("m.market_id = :market_id")
        params["market_id"] = market_id

    if include_failed:
        filters.append(
            "p.status IN "
            "('pending', 'failed', 'running')"
        )
    else:
        filters.append(
            "p.status IN ('pending', 'running')"
        )

    limit_clause = ""

    if limit_markets is not None:
        limit_clause = "LIMIT :limit_markets"
        params["limit_markets"] = limit_markets

    query = text(
        f"""
        SELECT
            m.market_id,
            m.condition_id,
            m.question,
            m.investigation_domain,
            m.investigation_priority,
            m.volume
        FROM markets m
        JOIN trade_collection_progress p
          ON p.condition_id = m.condition_id
        WHERE {" AND ".join(filters)}
        ORDER BY
            CASE m.investigation_priority
                WHEN 'HIGH' THEN 1
                WHEN 'MEDIUM' THEN 2
                WHEN 'CONTROL' THEN 3
                ELSE 4
            END,
            m.volume DESC NULLS LAST
        {limit_clause}
        """
    )

    with engine.connect() as connection:
        return [
            dict(row)
            for row in connection.execute(
                query,
                params,
            ).mappings()
        ]


def collect_market(
    client: httpx.Client,
    market: dict[str, Any],
) -> None:
    condition_id = str(market["condition_id"])
    market_id = str(market["market_id"])

    with engine.begin() as connection:
        connection.execute(
            MARK_RUNNING,
            {"condition_id": condition_id},
        )

    print(
        f"\nmarket={market_id} "
        f"domain={market['investigation_domain']} "
        f"volume={market['volume']} "
        f"question={market['question']}",
        flush=True,
    )

    try:
        stored, windows = collect_window(
            client=client,
            condition_id=condition_id,
            start_ts=ANALYSIS_START_TS,
            end_ts=ANALYSIS_END_TS,
        )

        with engine.begin() as connection:
            connection.execute(
                MARK_COMPLETE,
                {
                    "condition_id": condition_id,
                    "trades_stored": stored,
                    "windows_processed": windows,
                },
            )

        print(
            f"completed market={market_id} "
            f"trades={stored} "
            f"windows={windows}",
            flush=True,
        )

    except (
        httpx.HTTPError,
        json.JSONDecodeError,
        OSError,
        RuntimeError,
        TypeError,
        ValueError,
    ) as exc:
        with engine.begin() as connection:
            connection.execute(
                MARK_FAILED,
                {
                    "condition_id": condition_id,
                    "last_error": str(exc)[:4000],
                },
            )

        print(
            f"failed market={market_id}: {exc}",
            flush=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Collect taker-side Polymarket trades "
            "for the frozen investigation universe."
        )
    )
    parser.add_argument(
        "--limit-markets",
        type=int,
        default=None,
        help="Pilot limit.",
    )
    parser.add_argument(
        "--market-id",
        type=str,
        default=None,
        help="Collect one market only.",
    )
    parser.add_argument(
        "--include-failed",
        action="store_true",
        help="Retry previously failed markets.",
    )
    parser.add_argument(
        "--worker-index",
        type=int,
        default=0,
        help="Zero-based worker partition index.",
    )
    parser.add_argument(
        "--worker-count",
        type=int,
        default=1,
        help="Total number of worker partitions.",
    )
    args = parser.parse_args()

    if args.worker_count < 1:
        parser.error("--worker-count must be at least 1")

    if not 0 <= args.worker_index < args.worker_count:
        parser.error(
            "--worker-index must be between 0 "
            "and worker-count minus 1"
        )

    markets = load_markets(
        limit_markets=args.limit_markets,
        market_id=args.market_id,
        include_failed=args.include_failed,
        worker_index=args.worker_index,
        worker_count=args.worker_count,
    )

    print(
        f"Worker {args.worker_index + 1}/"
        f"{args.worker_count}: "
        f"markets queued={len(markets):,}",
        flush=True,
    )

    with httpx.Client(
        base_url=DATA_API_BASE,
        timeout=90,
        follow_redirects=True,
        headers={
            "Accept": "application/json",
            "User-Agent": (
                "polymarket-insider-investigation/1.0"
            ),
        },
    ) as client:
        for index, market in enumerate(
            markets,
            start=1,
        ):
            print(
                f"\nprogress={index}/{len(markets)}",
                flush=True,
            )

            collect_market(
                client=client,
                market=market,
            )

            time.sleep(
                REQUEST_DELAY_SECONDS
                + random.uniform(0.05, 0.2)
            )


if __name__ == "__main__":
    main()
