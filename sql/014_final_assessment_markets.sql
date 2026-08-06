DROP TABLE IF EXISTS investigation_markets;

CREATE TABLE investigation_markets (
    market_id TEXT PRIMARY KEY,
    condition_id TEXT UNIQUE NOT NULL,
    market_family_key TEXT,
    investigation_domain TEXT NOT NULL,
    selection_bucket TEXT NOT NULL,
    is_control BOOLEAN NOT NULL DEFAULT FALSE,
    selection_reason TEXT NOT NULL,
    market_volume NUMERIC,
    selected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

WITH family_ranked AS (
    SELECT
        m.*,
        ROW_NUMBER() OVER (
            PARTITION BY
                m.investigation_domain,
                m.market_family_key
            ORDER BY m.volume DESC NULLS LAST
        ) AS family_rank
    FROM markets m
    WHERE m.investigation_selected = TRUE
      AND m.condition_id IS NOT NULL
),
selected AS (
    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PRIMARY_GEOPOLITICS'::TEXT AS selection_bucket,
            FALSE AS is_control,
            'Highest-volume geopolitical market from a distinct family'
                AS selection_reason,
            volume AS market_volume
        FROM family_ranked
        WHERE investigation_domain = 'GEOPOLITICS'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 30
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PRIMARY_POLITICS_MACRO',
            FALSE,
            'Highest-volume politics or macro market from a distinct family',
            volume
        FROM family_ranked
        WHERE investigation_domain = 'POLITICS_MACRO'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 15
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PRIMARY_CORPORATE',
            FALSE,
            'Highest-volume corporate disclosure market from a distinct family',
            volume
        FROM family_ranked
        WHERE investigation_domain = 'CORPORATE'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 12
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PRIMARY_LEGAL_REGULATORY',
            FALSE,
            'Highest-volume legal or regulatory market from a distinct family',
            volume
        FROM family_ranked
        WHERE investigation_domain = 'LEGAL_REGULATORY'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 8
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PRIMARY_CRYPTO',
            FALSE,
            'Highest-volume crypto disclosure market from a distinct family',
            volume
        FROM family_ranked
        WHERE investigation_domain = 'CRYPTO'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 10
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'REFERENCE_CONTROL',
            TRUE,
            'High-volume externally observable market used as a control',
            volume
        FROM family_ranked
        WHERE investigation_domain = 'MARKET_REFERENCE'
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 10
    )

    UNION ALL

    (
        SELECT
            market_id,
            condition_id,
            market_family_key,
            investigation_domain,
            'PUBLIC_OUTCOME_CONTROL',
            TRUE,
            'High-volume sports or entertainment market used as a control',
            volume
        FROM family_ranked
        WHERE investigation_domain IN (
            'SPORTS_ESPORTS',
            'ENTERTAINMENT'
        )
          AND family_rank = 1
        ORDER BY volume DESC NULLS LAST
        LIMIT 10
    )
)
INSERT INTO investigation_markets (
    market_id,
    condition_id,
    market_family_key,
    investigation_domain,
    selection_bucket,
    is_control,
    selection_reason,
    market_volume
)
SELECT DISTINCT ON (condition_id)
    market_id,
    condition_id,
    market_family_key,
    investigation_domain,
    selection_bucket,
    is_control,
    selection_reason,
    market_volume
FROM selected
ORDER BY condition_id, market_volume DESC NULLS LAST;

CREATE INDEX ix_investigation_markets_domain
ON investigation_markets(investigation_domain);

CREATE INDEX ix_investigation_markets_family
ON investigation_markets(market_family_key);
