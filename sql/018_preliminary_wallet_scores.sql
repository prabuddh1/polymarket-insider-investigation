DROP TABLE IF EXISTS analysis_wallet_scores;

CREATE TABLE analysis_wallet_scores AS
SELECT
    wf.*,

    CASE
        WHEN sensitive_quality_adjusted_pnl >= 100000
            THEN 10
        WHEN sensitive_quality_adjusted_pnl >= 25000
            THEN 8
        WHEN sensitive_quality_adjusted_pnl >= 5000
            THEN 5
        WHEN sensitive_quality_adjusted_pnl >= 1000
            THEN 2
        ELSE 0
    END AS profit_score,

    CASE
        WHEN largest_market_buy_cost >= 100000
            THEN 10
        WHEN largest_market_buy_cost >= 25000
            THEN 8
        WHEN largest_market_buy_cost >= 5000
            THEN 5
        WHEN largest_market_buy_cost >= 1000
            THEN 2
        ELSE 0
    END AS conviction_score,

    CASE
        WHEN low_probability_winner_markets >= 5
            THEN 15
        WHEN low_probability_winner_markets >= 3
            THEN 12
        WHEN low_probability_winner_markets = 2
            THEN 8
        WHEN low_probability_winner_markets = 1
            THEN 4
        ELSE 0
    END AS low_probability_entry_score,

    CASE
        WHEN profitable_sensitive_markets >= 8
            THEN 15
        WHEN profitable_sensitive_markets >= 5
            THEN 12
        WHEN profitable_sensitive_markets >= 3
            THEN 8
        WHEN profitable_sensitive_markets = 2
            THEN 4
        ELSE 0
    END AS repeated_success_score,

    CASE
        WHEN families_traded >= 10
            THEN 10
        WHEN families_traded >= 6
            THEN 7
        WHEN families_traded >= 3
            THEN 4
        ELSE 0
    END AS cross_family_score,

    CASE
        WHEN primary_domain_concentration >= 0.90
         AND sensitive_markets_traded >= 3
            THEN 10
        WHEN primary_domain_concentration >= 0.75
         AND sensitive_markets_traded >= 3
            THEN 7
        WHEN primary_domain_concentration >= 0.60
         AND sensitive_markets_traded >= 2
            THEN 4
        ELSE 0
    END AS specialization_score,

    CASE
        WHEN sensitive_markets_traded = 1
         AND largest_market_buy_cost >= 25000
            THEN 5
        WHEN sensitive_markets_traded <= 3
         AND largest_market_buy_cost >= 50000
            THEN 3
        ELSE 0
    END AS wallet_novelty_score,

    0::INTEGER AS public_event_timing_score,

    0::INTEGER AS verified_pre_event_markets

FROM analysis_wallet_features wf
WHERE total_traded_usd >= 100
  AND sensitive_markets_traded > 0;
