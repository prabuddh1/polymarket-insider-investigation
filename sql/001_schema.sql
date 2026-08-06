CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS collection_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running',
    request_count INTEGER NOT NULL DEFAULT 0,
    rows_received BIGINT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS raw_events (
    event_id TEXT PRIMARY KEY,
    payload JSONB NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw_markets (
    market_id TEXT PRIMARY KEY,
    condition_id TEXT,
    payload JSONB NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS markets (
    market_id TEXT PRIMARY KEY,
    event_id TEXT,
    condition_id TEXT UNIQUE,
    question TEXT NOT NULL,
    slug TEXT,
    event_slug TEXT,
    description TEXT,
    resolution_source TEXT,
    category TEXT,
    information_type TEXT,
    created_at TIMESTAMPTZ,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    active BOOLEAN,
    closed BOOLEAN,
    archived BOOLEAN,
    volume NUMERIC,
    liquidity NUMERIC,
    winning_outcome TEXT,
    included_in_scope BOOLEAN NOT NULL DEFAULT FALSE,
    scope_reason TEXT,
    raw_payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_markets_scope
ON markets(included_in_scope);

CREATE INDEX IF NOT EXISTS ix_markets_dates
ON markets(end_at, resolved_at);

CREATE TABLE IF NOT EXISTS market_tokens (
    asset_id TEXT PRIMARY KEY,
    market_id TEXT NOT NULL REFERENCES markets(market_id),
    condition_id TEXT,
    outcome TEXT NOT NULL,
    outcome_index INTEGER,
    final_price NUMERIC,
    winner BOOLEAN
);

CREATE TABLE IF NOT EXISTS trades (
    trade_key TEXT PRIMARY KEY,
    transaction_hash TEXT,
    proxy_wallet TEXT NOT NULL,
    condition_id TEXT NOT NULL,
    asset_id TEXT,
    market_id TEXT,
    event_slug TEXT,
    market_slug TEXT,
    title TEXT,
    outcome TEXT,
    outcome_index INTEGER,
    side TEXT NOT NULL,
    price NUMERIC NOT NULL,
    shares NUMERIC NOT NULL,
    notional_usdc NUMERIC NOT NULL,
    traded_at TIMESTAMPTZ NOT NULL,
    raw_payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_trades_wallet_time
ON trades(proxy_wallet, traded_at);

CREATE INDEX IF NOT EXISTS ix_trades_market_time
ON trades(market_id, traded_at);

CREATE INDEX IF NOT EXISTS ix_trades_condition_time
ON trades(condition_id, traded_at);

CREATE TABLE IF NOT EXISTS price_history (
    asset_id TEXT NOT NULL,
    observed_at TIMESTAMPTZ NOT NULL,
    price NUMERIC NOT NULL,
    fidelity_minutes INTEGER,
    PRIMARY KEY(asset_id, observed_at)
);

CREATE TABLE IF NOT EXISTS public_event_timeline (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    market_id TEXT NOT NULL REFERENCES markets(market_id),
    event_type TEXT NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    source_name TEXT NOT NULL,
    source_url TEXT NOT NULL,
    source_tier INTEGER NOT NULL,
    timestamp_confidence TEXT NOT NULL,
    description TEXT,
    analyst_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet_market_features (
    proxy_wallet TEXT NOT NULL,
    market_id TEXT NOT NULL REFERENCES markets(market_id),
    first_trade_at TIMESTAMPTZ,
    last_trade_at TIMESTAMPTZ,
    fill_count INTEGER,
    buy_notional NUMERIC,
    sell_notional NUMERIC,
    gross_notional NUMERIC,
    net_shares NUMERIC,
    estimated_cost NUMERIC,
    average_entry_price NUMERIC,
    estimated_settlement_value NUMERIC,
    estimated_profit NUMERIC,
    estimated_roi NUMERIC,
    market_concentration NUMERIC,
    market_size_percentile NUMERIC,
    entry_probability NUMERIC,
    two_sided_ratio NUMERIC,
    minutes_before_public_event NUMERIC,
    pre_event_accumulation_ratio NUMERIC,
    feature_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY(proxy_wallet, market_id)
);

CREATE TABLE IF NOT EXISTS wallet_market_scores (
    proxy_wallet TEXT NOT NULL,
    market_id TEXT NOT NULL REFERENCES markets(market_id),
    score_version TEXT NOT NULL,
    timing_score NUMERIC NOT NULL DEFAULT 0,
    sizing_score NUMERIC NOT NULL DEFAULT 0,
    concentration_score NUMERIC NOT NULL DEFAULT 0,
    longshot_score NUMERIC NOT NULL DEFAULT 0,
    lifecycle_score NUMERIC NOT NULL DEFAULT 0,
    repetition_score NUMERIC NOT NULL DEFAULT 0,
    coordination_score NUMERIC NOT NULL DEFAULT 0,
    public_information_deduction NUMERIC NOT NULL DEFAULT 0,
    market_maker_deduction NUMERIC NOT NULL DEFAULT 0,
    data_quality_multiplier NUMERIC NOT NULL DEFAULT 1,
    raw_score NUMERIC NOT NULL,
    final_score NUMERIC NOT NULL,
    risk_band TEXT NOT NULL,
    triggered_heuristics JSONB NOT NULL DEFAULT '[]'::jsonb,
    PRIMARY KEY(proxy_wallet, market_id, score_version)
);

CREATE TABLE IF NOT EXISTS wallet_scores (
    proxy_wallet TEXT NOT NULL,
    score_version TEXT NOT NULL,
    markets_traded INTEGER,
    suspicious_markets INTEGER,
    total_notional NUMERIC,
    estimated_profit NUMERIC,
    highest_market_score NUMERIC,
    aggregate_score NUMERIC,
    risk_band TEXT,
    summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY(proxy_wallet, score_version)
);

CREATE TABLE IF NOT EXISTS case_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proxy_wallet TEXT NOT NULL,
    market_id TEXT NOT NULL REFERENCES markets(market_id),
    status TEXT NOT NULL DEFAULT 'pending',
    analyst_assessment TEXT,
    alternative_explanations TEXT,
    attribution_confidence TEXT,
    data_quality TEXT,
    reviewed_at TIMESTAMPTZ
);
