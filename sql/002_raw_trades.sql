CREATE TABLE IF NOT EXISTS raw_trades (
    trade_key TEXT PRIMARY KEY,
    transaction_hash TEXT,
    condition_id TEXT,
    proxy_wallet TEXT,
    traded_at TIMESTAMPTZ,
    payload JSONB NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_raw_trades_condition
ON raw_trades(condition_id);

CREATE INDEX IF NOT EXISTS ix_raw_trades_wallet
ON raw_trades(proxy_wallet);

CREATE INDEX IF NOT EXISTS ix_raw_trades_time
ON raw_trades(traded_at);
