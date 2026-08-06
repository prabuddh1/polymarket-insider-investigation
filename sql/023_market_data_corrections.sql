CREATE TABLE IF NOT EXISTS market_data_corrections (
    correction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    market_id TEXT NOT NULL,
    field_name TEXT NOT NULL,
    original_value TEXT,
    corrected_value TEXT,
    correction_reason TEXT NOT NULL,
    evidence TEXT,
    corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (market_id, field_name)
);

INSERT INTO market_data_corrections (
    market_id,
    field_name,
    original_value,
    corrected_value,
    correction_reason,
    evidence
)
VALUES (
    '1198423',
    'end_at',
    '2026-01-31T00:00:00Z',
    '2026-02-28T00:00:00Z',
    'Gamma endDate conflicts with the explicit market question and observed trading period',
    'Question says February 28, 2026; trades continued through February 28 and market closed February 28'
)
ON CONFLICT (market_id, field_name)
DO NOTHING;

UPDATE markets
SET end_at = TIMESTAMPTZ '2026-02-28 00:00:00+00'
WHERE market_id = '1198423';

UPDATE analysis_trades
SET end_at = TIMESTAMPTZ '2026-02-28 00:00:00+00'
WHERE market_id = '1198423';

UPDATE analysis_wallet_market_features
SET end_at = TIMESTAMPTZ '2026-02-28 00:00:00+00'
WHERE market_id = '1198423';
