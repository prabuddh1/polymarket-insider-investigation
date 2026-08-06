UPDATE analysis_wallet_scores ws
SET
    public_event_timing_score =
        COALESCE(te.public_event_timing_score, 0),

    verified_pre_event_markets =
        COALESCE(te.verified_pre_event_markets, 0),

    total_score =
          ws.profit_score
        + ws.conviction_score
        + ws.low_probability_entry_score
        + ws.repeated_success_score
        + ws.cross_family_score
        + ws.specialization_score
        + ws.wallet_novelty_score
        + COALESCE(
            te.public_event_timing_score,
            0
        )
FROM analysis_wallet_timing_evidence te
WHERE te.proxy_wallet = ws.proxy_wallet;

-- Reset wallets that did not have a verified event-timed entry.
UPDATE analysis_wallet_scores ws
SET
    public_event_timing_score = 0,
    verified_pre_event_markets = 0,
    total_score =
          ws.profit_score
        + ws.conviction_score
        + ws.low_probability_entry_score
        + ws.repeated_success_score
        + ws.cross_family_score
        + ws.specialization_score
        + ws.wallet_novelty_score
WHERE NOT EXISTS (
    SELECT 1
    FROM analysis_wallet_timing_evidence te
    WHERE te.proxy_wallet = ws.proxy_wallet
);

ANALYZE analysis_wallet_scores;
