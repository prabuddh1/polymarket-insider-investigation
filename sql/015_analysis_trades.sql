DROP TABLE IF EXISTS analysis_trades;

CREATE TABLE analysis_trades AS
SELECT
    rt.trade_key,
    rt.transaction_hash,
    m.market_id,
    rt.condition_id,
    rt.payload->>'asset' AS asset_id,
    LOWER(rt.proxy_wallet) AS proxy_wallet,
    UPPER(rt.payload->>'side') AS side,
    rt.payload->>'outcome' AS outcome,
    NULLIF(rt.payload->>'outcomeIndex', '')::INTEGER
        AS outcome_index,
    NULLIF(rt.payload->>'price', '')::NUMERIC
        AS price,
    NULLIF(rt.payload->>'size', '')::NUMERIC
        AS size,
    (
        NULLIF(rt.payload->>'price', '')::NUMERIC
        *
        NULLIF(rt.payload->>'size', '')::NUMERIC
    ) AS notional_usd,
    rt.traded_at,
    m.question,
    m.investigation_domain,
    m.market_family_key,
    m.end_at,
    m.closed_at,
    m.winning_outcome,
    im.selection_bucket,
    im.is_control
FROM raw_trades rt
JOIN markets m
  ON m.condition_id = rt.condition_id
JOIN investigation_markets im
  ON im.condition_id = rt.condition_id
WHERE rt.proxy_wallet IS NOT NULL
  AND rt.proxy_wallet <> ''
  AND rt.payload->>'price' IS NOT NULL
  AND rt.payload->>'size' IS NOT NULL;

ALTER TABLE analysis_trades
ADD PRIMARY KEY (trade_key);

CREATE INDEX ix_analysis_trades_wallet
ON analysis_trades(proxy_wallet);

CREATE INDEX ix_analysis_trades_market
ON analysis_trades(market_id);

CREATE INDEX ix_analysis_trades_wallet_market
ON analysis_trades(proxy_wallet, market_id);

CREATE INDEX ix_analysis_trades_time
ON analysis_trades(traded_at);

ANALYZE analysis_trades;
