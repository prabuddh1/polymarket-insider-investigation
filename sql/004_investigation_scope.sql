ALTER TABLE markets
ADD COLUMN IF NOT EXISTS investigation_priority TEXT;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS investigation_selected BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS investigation_reason TEXT;

CREATE INDEX IF NOT EXISTS ix_markets_investigation_selected
ON markets(investigation_selected, investigation_priority);
