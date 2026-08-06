DROP TABLE IF EXISTS market_families;

CREATE TABLE market_families AS
SELECT
    market_family_key,

    MODE() WITHIN GROUP (
        ORDER BY investigation_domain
    ) AS dominant_domain,

    MODE() WITHIN GROUP (
        ORDER BY information_type
    ) AS dominant_information_type,

    MODE() WITHIN GROUP (
        ORDER BY expected_information_source
    ) AS expected_information_source,

    COUNT(*) AS market_count,
    SUM(COALESCE(volume, 0)) AS family_volume,
    SUM(COALESCE(liquidity, 0)) AS family_liquidity,

    MIN(start_at) AS first_market_start,
    MAX(end_at) AS last_market_end,
    AVG(market_duration_minutes) AS average_duration_minutes,

    (
        ARRAY_AGG(
            market_id
            ORDER BY volume DESC NULLS LAST
        )
    )[1] AS largest_market_id,

    (
        ARRAY_AGG(
            question
            ORDER BY volume DESC NULLS LAST
        )
    )[1] AS representative_question

FROM markets
WHERE investigation_selected = TRUE
  AND market_family_key IS NOT NULL
  AND market_family_key <> ''
GROUP BY market_family_key;

ALTER TABLE market_families
ADD PRIMARY KEY (market_family_key);

CREATE INDEX ix_market_families_volume
ON market_families(family_volume DESC);

CREATE INDEX ix_market_families_domain
ON market_families(dominant_domain);
