DROP TABLE IF EXISTS analysis_market_summary;

CREATE TABLE analysis_market_summary AS
SELECT
    im.market_id,
    im.condition_id,
    im.market_family_key,
    im.investigation_domain,
    im.selection_bucket,
    im.is_control,
    im.selection_reason,
    im.market_volume,

    m.question,
    m.start_at,
    m.end_at,
    m.closed_at,
    m.winning_outcome,

    COUNT(DISTINCT at.trade_key)
        AS observed_trades,

    COUNT(DISTINCT at.proxy_wallet)
        AS observed_wallets,

    SUM(at.notional_usd)
        AS observed_notional_usd,

    COUNT(DISTINCT wmf.proxy_wallet) FILTER (
        WHERE wmf.material_low_probability_winner_entry
    ) AS low_probability_winner_wallets,

    COUNT(DISTINCT wmf.proxy_wallet) FILTER (
        WHERE wmf.quality_adjusted_profitable_market
    ) AS quality_adjusted_profitable_wallets,

    MAX(ape.public_event_time)
        AS verified_public_event_time,

    MAX(ape.source_name)
        AS verified_event_source

FROM investigation_markets im
JOIN markets m
  ON m.market_id = im.market_id
LEFT JOIN analysis_trades at
  ON at.market_id = im.market_id
LEFT JOIN analysis_wallet_market_features wmf
  ON wmf.market_id = im.market_id
LEFT JOIN analysis_public_events ape
  ON ape.market_id = im.market_id
GROUP BY
    im.market_id,
    im.condition_id,
    im.market_family_key,
    im.investigation_domain,
    im.selection_bucket,
    im.is_control,
    im.selection_reason,
    im.market_volume,
    m.question,
    m.start_at,
    m.end_at,
    m.closed_at,
    m.winning_outcome;

DROP TABLE IF EXISTS analysis_event_summary;

CREATE TABLE analysis_event_summary AS
SELECT
    ape.market_id,
    ape.market_family_key,
    m.question,
    m.winning_outcome,
    ape.public_event_time,
    ape.headline,
    ape.source_name,
    ape.source_url,
    ape.source_type,
    ape.timestamp_confidence,
    ape.timing_method,

    COUNT(DISTINCT wmf.proxy_wallet) FILTER (
        WHERE wmf.winner_entry_minutes_before_event > 0
    ) AS pre_event_winner_buyers,

    COUNT(DISTINCT wmf.proxy_wallet) FILTER (
        WHERE wmf.winner_entry_minutes_before_event
              BETWEEN 0 AND 15
    ) AS winner_buyers_within_15_minutes,

    COUNT(DISTINCT wmf.proxy_wallet) FILTER (
        WHERE wmf.winner_entry_minutes_before_event > 15
          AND wmf.winner_entry_minutes_before_event <= 60
    ) AS winner_buyers_15_to_60_minutes,

    SUM(wmf.winning_buy_cost) FILTER (
        WHERE wmf.winner_entry_minutes_before_event > 0
    ) AS pre_event_winning_buy_cost,

    SUM(wmf.gross_winner_purchase_edge) FILTER (
        WHERE wmf.winner_entry_minutes_before_event > 0
    ) AS pre_event_gross_winner_edge

FROM analysis_public_events ape
JOIN markets m
  ON m.market_id = ape.market_id
LEFT JOIN analysis_wallet_market_features wmf
  ON wmf.market_id = ape.market_id
GROUP BY
    ape.market_id,
    ape.market_family_key,
    m.question,
    m.winning_outcome,
    ape.public_event_time,
    ape.headline,
    ape.source_name,
    ape.source_url,
    ape.source_type,
    ape.timestamp_confidence,
    ape.timing_method;

ANALYZE analysis_market_summary;
ANALYZE analysis_event_summary;
