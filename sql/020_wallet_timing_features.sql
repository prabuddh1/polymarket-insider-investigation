ALTER TABLE analysis_wallet_market_features
ADD COLUMN IF NOT EXISTS public_event_time TIMESTAMPTZ;

ALTER TABLE analysis_wallet_market_features
ADD COLUMN IF NOT EXISTS public_event_source TEXT;

ALTER TABLE analysis_wallet_market_features
ADD COLUMN IF NOT EXISTS public_event_confidence TEXT;

ALTER TABLE analysis_wallet_market_features
ADD COLUMN IF NOT EXISTS timing_method TEXT;

ALTER TABLE analysis_wallet_market_features
ADD COLUMN IF NOT EXISTS winner_entry_minutes_before_event NUMERIC;

UPDATE analysis_wallet_market_features
SET
    public_event_time = NULL,
    public_event_source = NULL,
    public_event_confidence = NULL,
    timing_method = NULL,
    winner_entry_minutes_before_event = NULL;

WITH exact_market_event AS (
    SELECT DISTINCT ON (market_id)
        market_id,
        public_event_time,
        source_name,
        timestamp_confidence,
        timing_method
    FROM analysis_public_events
    WHERE market_id IS NOT NULL
    ORDER BY
        market_id,
        public_event_time
)
UPDATE analysis_wallet_market_features wmf
SET
    public_event_time =
        event.public_event_time,

    public_event_source =
        event.source_name,

    public_event_confidence =
        event.timestamp_confidence,

    timing_method =
        event.timing_method,

    winner_entry_minutes_before_event =
        EXTRACT(
            EPOCH FROM (
                event.public_event_time
                - wmf.winning_side_first_buy_at
            )
        ) / 60

FROM exact_market_event event
WHERE event.market_id = wmf.market_id
  AND wmf.winning_side_first_buy_at IS NOT NULL;

ANALYZE analysis_wallet_market_features;
