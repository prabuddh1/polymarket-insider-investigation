ALTER TABLE markets
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS open_interest NUMERIC;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS enable_order_book BOOLEAN;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS screening_eligible BOOLEAN;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS exclusion_reason TEXT;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS market_duration_minutes NUMERIC;

CREATE INDEX IF NOT EXISTS ix_markets_condition_id
ON markets(condition_id);

CREATE INDEX IF NOT EXISTS ix_markets_information_type
ON markets(information_type);

CREATE INDEX IF NOT EXISTS ix_markets_scope_dates
ON markets(included_in_scope, end_at, closed_at);

CREATE INDEX IF NOT EXISTS ix_markets_screening
ON markets(screening_eligible, information_type);

CREATE INDEX IF NOT EXISTS ix_markets_volume
ON markets(volume DESC);
