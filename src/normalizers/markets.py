import json
import re
from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy import text

from src.common.db import engine

BATCH_SIZE = 5000


def parse_json_array(value: Any) -> list[Any]:
    if value is None:
        return []

    if isinstance(value, list):
        return value

    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return []

        return parsed if isinstance(parsed, list) else []

    return []


def parse_datetime(value: Any) -> datetime | None:
    if value in (None, ""):
        return None

    try:
        return datetime.fromisoformat(
            str(value).replace("Z", "+00:00")
        )
    except ValueError:
        return None


def parse_decimal(value: Any) -> Decimal | None:
    if value in (None, ""):
        return None

    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None


def matches_any(
    content: str,
    patterns: tuple[str, ...],
) -> bool:
    return any(
        re.search(pattern, content, flags=re.IGNORECASE)
        for pattern in patterns
    )


def classify_information_type(
    question: str,
    description: str,
    category: str,
) -> str:
    content = f"{question} {description} {category}".lower()

    sports_patterns = (
        r"\bvs\.?\b",
        r"\bversus\b",
        r"\bnba\b",
        r"\bnfl\b",
        r"\bnhl\b",
        r"\bmlb\b",
        r"\buefa\b",
        r"\bpremier league\b",
        r"\bchampions league\b",
        r"\bworld cup\b",
        r"\bcounter-strike\b",
        r"\bbo[135]\b",
        r"\besports?\b",
        r"\bplayoffs?\b",
        r"\bgame of the year\b",
        r"\bacademy awards?\b",
        r"\boscar(?:s)?\b",
        r"\bgrammy(?:s)?\b",
        r"\baward(?:s)?\b",
    )

    reference_patterns = (
        r"\bwti\b",
        r"\bcrude oil\b",
        r"\boil price\b",
        r"\bbitcoin price\b",
        r"\bbtc price\b",
        r"\bethereum price\b",
        r"\beth price\b",
        r"\bxrp price\b",
        r"\bsolana price\b",
        r"\bgold price\b",
        r"\bnasdaq\b",
        r"\bs&p 500\b",
        r"\bdow jones\b",
        r"\bup or down\b",
    )

    geopolitical_patterns = (
        r"\bwar\b",
        r"\bmilitary action\b",
        r"\bmilitary operation(?:s)?\b",
        r"\bairstrike(?:s)?\b",
        r"\bmissile(?:s)?\b",
        r"\binvasion\b",
        r"\bceasefire\b",
        r"\bsanction(?:s)?\b",
        r"\btroop(?:s)?\b",
        r"\bdeclare war\b",
        r"\bstrike(?:s|d)? iran\b",
        r"\bstrike(?:s|d)? israel\b",
        r"\bstrike(?:s|d)? lebanon\b",
        r"\bstrike(?:s|d)? ukraine\b",
        r"\bstrike(?:s|d)? russia\b",
        r"\bnuclear facilit(?:y|ies)\b",
        r"\bstrait of hormuz\b",
    )

    controlled_patterns = (
        r"\bannounce(?:s|d|ment)?\b",
        r"\bresign(?:s|ed|ation)?\b",
        r"\bappoint(?:s|ed|ment)?\b",
        r"\bapproval\b",
        r"\bcourt ruling\b",
        r"\bindict(?:s|ed|ment)?\b",
        r"\bcharged\b",
        r"\bproduct launch\b",
        r"\bceo\b",
        r"\bregulator\b",
        r"\bsec approval\b",
        r"\bfda approval\b",
        r"\bfederal reserve\b",
        r"\bearnings call\b",
        r"\bbtc purchase\b",
    )

    if matches_any(content, sports_patterns):
        return "PUBLIC_COMPETITION"

    if matches_any(content, reference_patterns):
        return "REFERENCE_MARKET"

    if matches_any(content, geopolitical_patterns):
        return "OSINT_INTENSIVE"

    if matches_any(content, controlled_patterns):
        return "CONTROLLED_DISCLOSURE"

    return "OTHER"

def determine_screening_eligibility(
    question: str,
    information_type: str,
    start_at: datetime | None,
    end_at: datetime | None,
) -> tuple[bool, str | None, Decimal | None]:
    duration_minutes: Decimal | None = None

    if start_at and end_at:
        duration_seconds = Decimal(
            str((end_at - start_at).total_seconds())
        )
        duration_minutes = duration_seconds / Decimal(60)

    normalized_question = question.lower()

    if (
        "up or down" in normalized_question
        and duration_minutes is not None
        and duration_minutes <= Decimal(1440)
    ):
        return (
            False,
            "short_horizon_crypto_price_contract",
            duration_minutes,
        )

    if (
        information_type == "REFERENCE_MARKET"
        and duration_minutes is not None
        and duration_minutes <= Decimal(60)
    ):
        return (
            False,
            "short_horizon_reference_market",
            duration_minutes,
        )

    return True, None, duration_minutes


MARKET_UPSERT = text(
    """
    INSERT INTO markets (
        market_id,
        event_id,
        condition_id,
        question,
        slug,
        event_slug,
        description,
        resolution_source,
        category,
        information_type,
        created_at,
        updated_at,
        start_at,
        end_at,
        closed_at,
        resolved_at,
        active,
        closed,
        archived,
        enable_order_book,
        volume,
        liquidity,
        open_interest,
        winning_outcome,
        included_in_scope,
        scope_reason,
        screening_eligible,
        exclusion_reason,
        market_duration_minutes,
        raw_payload
    )
    VALUES (
        :market_id,
        :event_id,
        :condition_id,
        :question,
        :slug,
        :event_slug,
        :description,
        :resolution_source,
        :category,
        :information_type,
        :created_at,
        :updated_at,
        :start_at,
        :end_at,
        :closed_at,
        :resolved_at,
        :active,
        :closed,
        :archived,
        :enable_order_book,
        :volume,
        :liquidity,
        :open_interest,
        :winning_outcome,
        TRUE,
        'end_date_in_assessment_window',
        :screening_eligible,
        :exclusion_reason,
        :market_duration_minutes,
        CAST(:raw_payload AS JSONB)
    )
    ON CONFLICT (market_id)
    DO UPDATE SET
        event_id = EXCLUDED.event_id,
        condition_id = EXCLUDED.condition_id,
        question = EXCLUDED.question,
        slug = EXCLUDED.slug,
        event_slug = EXCLUDED.event_slug,
        description = EXCLUDED.description,
        resolution_source = EXCLUDED.resolution_source,
        category = EXCLUDED.category,
        information_type = EXCLUDED.information_type,
        created_at = EXCLUDED.created_at,
        updated_at = EXCLUDED.updated_at,
        start_at = EXCLUDED.start_at,
        end_at = EXCLUDED.end_at,
        closed_at = EXCLUDED.closed_at,
        resolved_at = EXCLUDED.resolved_at,
        active = EXCLUDED.active,
        closed = EXCLUDED.closed,
        archived = EXCLUDED.archived,
        enable_order_book = EXCLUDED.enable_order_book,
        volume = EXCLUDED.volume,
        liquidity = EXCLUDED.liquidity,
        open_interest = EXCLUDED.open_interest,
        winning_outcome = EXCLUDED.winning_outcome,
        included_in_scope = TRUE,
        scope_reason = EXCLUDED.scope_reason,
        screening_eligible = EXCLUDED.screening_eligible,
        exclusion_reason = EXCLUDED.exclusion_reason,
        market_duration_minutes = EXCLUDED.market_duration_minutes,
        raw_payload = EXCLUDED.raw_payload
    """
)


TOKEN_UPSERT = text(
    """
    INSERT INTO market_tokens (
        asset_id,
        market_id,
        condition_id,
        outcome,
        outcome_index,
        final_price,
        winner
    )
    VALUES (
        :asset_id,
        :market_id,
        :condition_id,
        :outcome,
        :outcome_index,
        :final_price,
        :winner
    )
    ON CONFLICT (asset_id)
    DO UPDATE SET
        market_id = EXCLUDED.market_id,
        condition_id = EXCLUDED.condition_id,
        outcome = EXCLUDED.outcome,
        outcome_index = EXCLUDED.outcome_index,
        final_price = EXCLUDED.final_price,
        winner = EXCLUDED.winner
    """
)


def transform_market(
    market_id: str,
    payload: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    question = str(payload.get("question") or "")
    description = str(payload.get("description") or "")
    category = str(payload.get("category") or "")

    created_at = parse_datetime(payload.get("createdAt"))
    updated_at = parse_datetime(payload.get("updatedAt"))
    start_at = parse_datetime(payload.get("startDate"))
    end_at = parse_datetime(
        payload.get("endDate")
        or payload.get("endDateIso")
    )
    closed_at = parse_datetime(payload.get("closedTime"))
    resolved_at = parse_datetime(payload.get("resolvedAt"))

    information_type = classify_information_type(
        question,
        description,
        category,
    )

    (
        screening_eligible,
        exclusion_reason,
        duration_minutes,
    ) = determine_screening_eligibility(
        question,
        information_type,
        start_at,
        end_at,
    )

    outcomes = parse_json_array(payload.get("outcomes"))
    prices = parse_json_array(payload.get("outcomePrices"))
    token_ids = parse_json_array(payload.get("clobTokenIds"))

    winning_outcome: str | None = None
    token_rows: list[dict[str, Any]] = []

    for index, outcome in enumerate(outcomes):
        final_price = (
            parse_decimal(prices[index])
            if index < len(prices)
            else None
        )

        winner = final_price == Decimal(1)

        if winner:
            winning_outcome = str(outcome)

        if index >= len(token_ids):
            continue

        token_rows.append(
            {
                "asset_id": str(token_ids[index]),
                "market_id": market_id,
                "condition_id": payload.get("conditionId"),
                "outcome": str(outcome),
                "outcome_index": index,
                "final_price": final_price,
                "winner": winner,
            }
        )

    events = payload.get("events")
    event = (
        events[0]
        if isinstance(events, list) and events
        else {}
    )

    market_row = {
        "market_id": market_id,
        "event_id": (
            str(event.get("id"))
            if event.get("id") is not None
            else None
        ),
        "condition_id": payload.get("conditionId"),
        "question": question,
        "slug": payload.get("slug"),
        "event_slug": event.get("slug"),
        "description": description,
        "resolution_source": (
            payload.get("resolutionSource")
            or event.get("resolutionSource")
        ),
        "category": category or event.get("category"),
        "information_type": information_type,
        "created_at": created_at,
        "updated_at": updated_at,
        "start_at": start_at,
        "end_at": end_at,
        "closed_at": closed_at,
        "resolved_at": resolved_at,
        "active": payload.get("active"),
        "closed": payload.get("closed"),
        "archived": payload.get("archived"),
        "enable_order_book": payload.get("enableOrderBook"),
        "volume": parse_decimal(payload.get("volume")),
        "liquidity": parse_decimal(payload.get("liquidity")),
        "open_interest": parse_decimal(
            payload.get("openInterest")
        ),
        "winning_outcome": winning_outcome,
        "screening_eligible": screening_eligible,
        "exclusion_reason": exclusion_reason,
        "market_duration_minutes": duration_minutes,
        "raw_payload": json.dumps(payload),
    }

    return market_row, token_rows


def normalize() -> None:
    last_market_id = ""
    processed = 0

    while True:
        with engine.connect() as connection:
            rows = connection.execute(
                text(
                    """
                    SELECT market_id, payload
                    FROM raw_markets
                    WHERE market_id > :last_market_id
                    ORDER BY market_id
                    LIMIT :batch_size
                    """
                ),
                {
                    "last_market_id": last_market_id,
                    "batch_size": BATCH_SIZE,
                },
            ).mappings().all()

        if not rows:
            break

        market_rows: list[dict[str, Any]] = []
        token_rows: list[dict[str, Any]] = []

        for row in rows:
            market_row, market_tokens = transform_market(
                str(row["market_id"]),
                row["payload"],
            )
            market_rows.append(market_row)
            token_rows.extend(market_tokens)

        with engine.begin() as connection:
            connection.execute(MARKET_UPSERT, market_rows)

            if token_rows:
                connection.execute(TOKEN_UPSERT, token_rows)

        last_market_id = str(rows[-1]["market_id"])
        processed += len(rows)

        print(
            f"Normalized {processed:,} markets",
            flush=True,
        )

    print("Market normalization complete", flush=True)


if __name__ == "__main__":
    normalize()
