CREATE TABLE IF NOT EXISTS trade_collection_progress (
    condition_id TEXT PRIMARY KEY,
    market_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    attempts INTEGER NOT NULL DEFAULT 0,
    trades_stored BIGINT NOT NULL DEFAULT 0,
    windows_processed INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_trade_collection_progress_status
ON trade_collection_progress(status);

CREATE INDEX IF NOT EXISTS ix_raw_trades_market_time
ON raw_trades(condition_id, traded_at);

CREATE INDEX IF NOT EXISTS ix_raw_trades_tx
ON raw_trades(transaction_hash);
