import pandas as pd

from src.common.config import settings
from src.common.db import engine


def export() -> None:
    settings.artifact_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    markets = pd.read_sql(
        """
        SELECT
            m.market_id,
            m.event_id,
            m.condition_id,
            m.question,
            m.slug,
            m.event_slug,
            m.information_type,
            m.investigation_domain,
            m.expected_information_source,
            m.investigation_priority,
            m.investigation_reason,
            m.market_family_key,
            f.market_count AS family_market_count,
            f.family_volume,
            m.created_at,
            m.start_at,
            m.end_at,
            m.closed_at,
            m.volume,
            m.liquidity,
            m.open_interest,
            m.winning_outcome
        FROM markets m
        LEFT JOIN market_families f
          ON f.market_family_key = m.market_family_key
        WHERE m.investigation_selected = TRUE
        ORDER BY
            CASE m.investigation_priority
                WHEN 'HIGH' THEN 1
                WHEN 'MEDIUM' THEN 2
                WHEN 'CONTROL' THEN 3
                ELSE 4
            END,
            m.volume DESC NULLS LAST
        """,
        engine,
    )

    families = pd.read_sql(
        """
        SELECT *
        FROM market_families
        ORDER BY family_volume DESC
        """,
        engine,
    )

    markets.to_csv(
        settings.artifact_dir
        / "03_investigation_market_universe.csv",
        index=False,
    )

    families.to_csv(
        settings.artifact_dir
        / "04_market_families.csv",
        index=False,
    )

    print(f"Exported {len(markets):,} selected markets")
    print(f"Exported {len(families):,} market families")


if __name__ == "__main__":
    export()
