ALTER TABLE markets
ADD COLUMN IF NOT EXISTS market_family_key TEXT;

UPDATE markets
SET market_family_key =
    LOWER(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                question,
                '\b(by|before|on|in)\s+[A-Z][A-Za-z]+\s+\d{1,2}(,\s+\d{4})?\b',
                '',
                'gi'
            ),
            '[^a-zA-Z0-9]+',
            '_',
            'g'
        )
    );

CREATE INDEX IF NOT EXISTS ix_markets_family
ON markets(market_family_key);
