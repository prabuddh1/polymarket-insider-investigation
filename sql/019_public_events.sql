DROP TABLE IF EXISTS analysis_public_events;

CREATE TABLE analysis_public_events (
    event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    market_family_key TEXT NOT NULL,

    public_event_time TIMESTAMPTZ NOT NULL,

    headline TEXT NOT NULL,

    source_name TEXT NOT NULL,

    source_url TEXT NOT NULL,

    source_type TEXT NOT NULL CHECK (
        source_type IN (
            'OFFICIAL',
            'PRIMARY_FILING',
            'REPUTABLE_NEWS',
            'OTHER_PUBLIC'
        )
    ),

    timestamp_confidence TEXT NOT NULL CHECK (
        timestamp_confidence IN (
            'HIGH',
            'MEDIUM',
            'LOW'
        )
    ),

    event_description TEXT,

    analyst_notes TEXT,

    verified_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    UNIQUE (
        market_family_key,
        public_event_time,
        source_url
    )
);

CREATE INDEX ix_public_events_family
ON analysis_public_events(market_family_key);

CREATE INDEX ix_public_events_time
ON analysis_public_events(public_event_time);
