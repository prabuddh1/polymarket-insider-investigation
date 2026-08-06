DROP TABLE IF EXISTS analysis_wallet_timing_evidence;

CREATE TABLE analysis_wallet_timing_evidence AS
WITH eligible_entries AS (
    SELECT
        proxy_wallet,
        market_id,
        question,
        investigation_domain,
        winning_side_first_buy_at,
        public_event_time,
        winner_entry_minutes_before_event,
        winning_side_average_entry,
        winning_buy_cost,
        gross_winner_purchase_edge,
        public_event_source,
        public_event_confidence,
        timing_method,
        has_observed_inventory_gap,

        CASE
            -- Strongest signal:
            -- meaningful position, low implied probability,
            -- and entry immediately before verified publication.
            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.50
             AND winner_entry_minutes_before_event
                 BETWEEN 0 AND 15
                THEN 25

            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.50
             AND winner_entry_minutes_before_event
                 > 15
             AND winner_entry_minutes_before_event <= 60
                THEN 22

            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.50
             AND winner_entry_minutes_before_event
                 > 60
             AND winner_entry_minutes_before_event <= 360
                THEN 16

            -- Moderate-probability entries.
            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.80
             AND winner_entry_minutes_before_event
                 BETWEEN 0 AND 15
                THEN 18

            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.80
             AND winner_entry_minutes_before_event
                 > 15
             AND winner_entry_minutes_before_event <= 60
                THEN 14

            WHEN winning_buy_cost >= 500
             AND winning_side_average_entry <= 0.80
             AND winner_entry_minutes_before_event
                 > 60
             AND winner_entry_minutes_before_event <= 360
                THEN 10

            -- Market was already strongly pricing the outcome.
            -- Keep only a small timing contribution.
            WHEN winning_buy_cost >= 1000
             AND winning_side_average_entry <= 0.95
             AND winner_entry_minutes_before_event
                 BETWEEN 0 AND 15
                THEN 6

            WHEN winning_buy_cost >= 1000
             AND winning_side_average_entry <= 0.95
             AND winner_entry_minutes_before_event
                 > 15
             AND winner_entry_minutes_before_event <= 60
                THEN 4

            ELSE 0
        END AS timing_evidence_score

    FROM analysis_wallet_market_features
    WHERE public_event_time IS NOT NULL
      AND public_event_confidence IN ('HIGH', 'MEDIUM')
      AND timing_method = 'PUBLIC_EVENT'
      AND winner_entry_minutes_before_event > 0
      AND winning_side_average_entry IS NOT NULL
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY proxy_wallet
            ORDER BY
                timing_evidence_score DESC,
                gross_winner_purchase_edge DESC,
                winning_buy_cost DESC
        ) AS evidence_rank,

        COUNT(*) FILTER (
            WHERE timing_evidence_score > 0
        ) OVER (
            PARTITION BY proxy_wallet
        ) AS verified_pre_event_markets
    FROM eligible_entries
)
SELECT
    proxy_wallet,
    market_id AS strongest_timing_market_id,
    question AS strongest_timing_market,
    investigation_domain AS timing_domain,
    winning_side_first_buy_at,
    public_event_time,
    winner_entry_minutes_before_event,
    winning_side_average_entry,
    winning_buy_cost,
    gross_winner_purchase_edge,
    public_event_source,
    public_event_confidence,
    timing_method,
    has_observed_inventory_gap,
    timing_evidence_score AS public_event_timing_score,
    verified_pre_event_markets
FROM ranked
WHERE evidence_rank = 1;

ALTER TABLE analysis_wallet_timing_evidence
ADD PRIMARY KEY (proxy_wallet);

CREATE INDEX ix_timing_evidence_score
ON analysis_wallet_timing_evidence(
    public_event_timing_score DESC
);

ANALYZE analysis_wallet_timing_evidence;
