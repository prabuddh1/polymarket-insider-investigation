DROP TABLE IF EXISTS analysis_wallet_features;

CREATE TABLE analysis_wallet_features AS
WITH domain_activity AS (
    SELECT
        proxy_wallet,
        investigation_domain,
        SUM(total_buy_cost) AS domain_buy_cost,
        COUNT(*) AS domain_markets
    FROM analysis_wallet_market_features
    WHERE is_control = FALSE
    GROUP BY
        proxy_wallet,
        investigation_domain
),
domain_ranked AS (
    SELECT
        proxy_wallet,
        investigation_domain,
        domain_buy_cost,
        domain_markets,
        ROW_NUMBER() OVER (
            PARTITION BY proxy_wallet
            ORDER BY domain_buy_cost DESC
        ) AS domain_rank
    FROM domain_activity
),
wallet_base AS (
    SELECT
        proxy_wallet,

        COUNT(*) AS markets_traded,
        COUNT(DISTINCT market_family_key)
            AS families_traded,
        COUNT(DISTINCT investigation_domain)
            AS domains_traded,

        COUNT(*) FILTER (
            WHERE is_control = FALSE
        ) AS sensitive_markets_traded,

        COUNT(*) FILTER (
            WHERE is_control = TRUE
        ) AS control_markets_traded,

        COUNT(*) FILTER (
            WHERE quality_adjusted_profitable_market
              AND is_control = FALSE
        ) AS profitable_sensitive_markets,

        COUNT(*) FILTER (
            WHERE material_low_probability_winner_entry
              AND is_control = FALSE
        ) AS low_probability_winner_markets,

        COUNT(*) FILTER (
            WHERE has_observed_inventory_gap = FALSE
        ) AS complete_inventory_markets,

        SUM(total_traded_usd)
            AS total_traded_usd,

        SUM(total_buy_cost)
            AS total_buy_cost,

        SUM(total_buy_cost) FILTER (
            WHERE is_control = FALSE
        ) AS sensitive_buy_cost,

        MAX(total_buy_cost)
            AS largest_market_buy_cost,

        MAX(largest_trade_usd)
            AS largest_trade_usd,

        SUM(
            observed_settlement_adjusted_pnl
        ) FILTER (
            WHERE has_observed_inventory_gap = FALSE
        ) AS quality_adjusted_estimated_pnl,

        SUM(
            observed_settlement_adjusted_pnl
        ) FILTER (
            WHERE has_observed_inventory_gap = FALSE
              AND is_control = FALSE
        ) AS sensitive_quality_adjusted_pnl,

        SUM(
            observed_settlement_adjusted_pnl
        ) FILTER (
            WHERE has_observed_inventory_gap = FALSE
              AND is_control = TRUE
        ) AS control_quality_adjusted_pnl,

        SUM(gross_winner_purchase_edge) FILTER (
            WHERE is_control = FALSE
        ) AS sensitive_gross_winner_edge,

        AVG(quality_adjusted_roi) FILTER (
            WHERE total_buy_cost >= 100
              AND has_observed_inventory_gap = FALSE
        ) AS average_quality_adjusted_roi,

        AVG(
            CASE
                WHEN quality_adjusted_profitable_market
                    THEN 1.0
                ELSE 0.0
            END
        ) FILTER (
            WHERE is_control = FALSE
              AND has_observed_inventory_gap = FALSE
        ) AS sensitive_quality_win_rate,

        MAX(
            CASE
                WHEN total_buy_cost > 0
                THEN winning_buy_cost_share
            END
        ) FILTER (
            WHERE is_control = FALSE
        ) AS maximum_winner_concentration,

        MIN(first_trade_at)
            AS first_observed_trade,

        MAX(last_trade_at)
            AS last_observed_trade,

        EXTRACT(
            EPOCH FROM (
                MAX(last_trade_at)
                - MIN(first_trade_at)
            )
        ) / 86400 AS observed_active_days

    FROM analysis_wallet_market_features
    GROUP BY proxy_wallet
)
SELECT
    wb.*,

    dr.investigation_domain
        AS primary_sensitive_domain,

    dr.domain_buy_cost
        AS primary_domain_buy_cost,

    CASE
        WHEN wb.sensitive_buy_cost > 0
        THEN dr.domain_buy_cost
             / wb.sensitive_buy_cost
    END AS primary_domain_concentration,

    CASE
        WHEN wb.total_buy_cost > 0
        THEN wb.largest_market_buy_cost
             / wb.total_buy_cost
    END AS largest_market_concentration

FROM wallet_base wb
LEFT JOIN domain_ranked dr
  ON dr.proxy_wallet = wb.proxy_wallet
 AND dr.domain_rank = 1;

CREATE INDEX ix_awf_sensitive_pnl
ON analysis_wallet_features(
    sensitive_quality_adjusted_pnl DESC
);

CREATE INDEX ix_awf_domain_concentration
ON analysis_wallet_features(
    primary_domain_concentration DESC
);

ANALYZE analysis_wallet_features;
