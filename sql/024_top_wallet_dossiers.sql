DROP TABLE IF EXISTS analysis_top_wallet_dossiers;

CREATE TABLE analysis_top_wallet_dossiers AS
WITH top_wallets AS (
    SELECT
        case_rank,
        proxy_wallet,
        total_score,
        priority_label
    FROM analysis_case_reviews
    WHERE case_rank <= 20
)
SELECT
    tw.case_rank,
    tw.proxy_wallet,
    tw.total_score,
    tw.priority_label,

    wmf.market_id,
    wmf.condition_id,
    wmf.question,
    wmf.market_family_key,
    wmf.investigation_domain,
    wmf.selection_bucket,
    wmf.is_control,
    wmf.winning_outcome,

    wmf.first_trade_at,
    wmf.winning_side_first_buy_at,
    wmf.last_trade_at,
    wmf.trade_count,

    wmf.total_traded_usd,
    wmf.total_buy_cost,
    wmf.total_sell_proceeds,
    wmf.largest_trade_usd,

    wmf.winning_buy_shares,
    wmf.winning_buy_cost,
    wmf.winning_side_average_entry,
    wmf.winning_buy_cost_share,

    wmf.observed_settlement_adjusted_pnl,
    wmf.quality_adjusted_roi,
    wmf.gross_winner_purchase_edge,
    wmf.has_observed_inventory_gap,

    wmf.public_event_time,
    wmf.public_event_source,
    wmf.public_event_confidence,
    wmf.winner_entry_minutes_before_event,

    wmf.quality_adjusted_profitable_market,
    wmf.material_low_probability_winner_entry

FROM top_wallets tw
JOIN analysis_wallet_market_features wmf
  ON wmf.proxy_wallet = tw.proxy_wallet
ORDER BY
    tw.case_rank,
    wmf.observed_settlement_adjusted_pnl DESC NULLS LAST,
    wmf.total_buy_cost DESC;

CREATE INDEX ix_top_dossiers_rank
ON analysis_top_wallet_dossiers(case_rank);

CREATE INDEX ix_top_dossiers_wallet
ON analysis_top_wallet_dossiers(proxy_wallet);

ANALYZE analysis_top_wallet_dossiers;
