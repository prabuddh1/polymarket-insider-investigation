ALTER TABLE markets
ADD COLUMN IF NOT EXISTS investigation_domain TEXT;

ALTER TABLE markets
ADD COLUMN IF NOT EXISTS expected_information_source TEXT;

CREATE INDEX IF NOT EXISTS ix_markets_investigation_domain
ON markets(investigation_domain);
