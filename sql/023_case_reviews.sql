DROP TABLE IF EXISTS analysis_case_reviews;

CREATE TABLE analysis_case_reviews AS
WITH ranked_wallets AS (
    SELECT
        ws.*,
        ROW_NUMBER() OVER (
            ORDER BY
                ws.total_score DESC,
                ws.sensitive_quality_adjusted_pnl DESC NULLS LAST,
                ws.proxy_wallet
        ) AS case_rank
    FROM analysis_wallet_scores ws
),
wallet_market_summary AS (
    SELECT
        wmf.proxy_wallet,

        ARRAY_AGG(
            DISTINCT wmf.market_family_key
            ORDER BY wmf.market_family_key
        ) FILTER (
            WHERE wmf.is_control = FALSE
        ) AS sensitive_families,

        ARRAY_AGG(
            DISTINCT wmf.question
            ORDER BY wmf.question
        ) FILTER (
            WHERE wmf.quality_adjusted_profitable_market
              AND wmf.is_control = FALSE
        ) AS profitable_sensitive_questions,

        COUNT(*) FILTER (
            WHERE wmf.has_observed_inventory_gap
        ) AS inventory_gap_market_count,

        COUNT(*) FILTER (
            WHERE wmf.public_event_time IS NOT NULL
              AND wmf.winner_entry_minutes_before_event > 0
        ) AS event_timed_market_count,

        MAX(wmf.total_buy_cost)
            AS largest_observed_market_buy_cost,

        MAX(wmf.gross_winner_purchase_edge)
            AS largest_observed_winner_edge

    FROM analysis_wallet_market_features wmf
    GROUP BY wmf.proxy_wallet
)
SELECT
    rw.case_rank,
    rw.proxy_wallet,
    rw.priority_label,
    rw.total_score,

    rw.public_event_timing_score,
    rw.verified_pre_event_markets,
    rw.profit_score,
    rw.conviction_score,
    rw.low_probability_entry_score,
    rw.repeated_success_score,
    rw.cross_family_score,
    rw.specialization_score,
    rw.wallet_novelty_score,

    rw.sensitive_quality_adjusted_pnl,
    rw.sensitive_gross_winner_edge,
    rw.sensitive_markets_traded,
    rw.profitable_sensitive_markets,
    rw.low_probability_winner_markets,
    rw.largest_market_buy_cost,
    rw.primary_sensitive_domain,
    rw.primary_domain_concentration,
    rw.largest_market_concentration,

    te.strongest_timing_market_id,
    te.strongest_timing_market,
    te.winning_side_first_buy_at,
    te.public_event_time,
    te.winner_entry_minutes_before_event,
    te.winning_side_average_entry,
    te.winning_buy_cost AS timing_market_buy_cost,
    te.gross_winner_purchase_edge AS timing_market_gross_edge,
    te.public_event_source,
    te.public_event_confidence,

    wms.inventory_gap_market_count,
    wms.event_timed_market_count,
    wms.largest_observed_market_buy_cost,
    wms.largest_observed_winner_edge,
    wms.sensitive_families,
    wms.profitable_sensitive_questions,

    NULL::TEXT AS analyst_summary,
    NULL::TEXT AS alternative_explanation,
    NULL::TEXT AS analyst_confidence,
    'PENDING'::TEXT AS review_status

FROM ranked_wallets rw
LEFT JOIN analysis_wallet_timing_evidence te
  ON te.proxy_wallet = rw.proxy_wallet
LEFT JOIN wallet_market_summary wms
  ON wms.proxy_wallet = rw.proxy_wallet
WHERE rw.case_rank <= 100
ORDER BY rw.case_rank;

ALTER TABLE analysis_case_reviews
ADD PRIMARY KEY (proxy_wallet);

CREATE UNIQUE INDEX ix_case_reviews_rank
ON analysis_case_reviews(case_rank);

ANALYZE analysis_case_reviews;
