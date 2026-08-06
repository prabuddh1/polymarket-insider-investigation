DROP TABLE IF EXISTS analysis_wallet_market_features;

CREATE TABLE analysis_wallet_market_features AS
WITH outcome_activity AS (
    SELECT
        proxy_wallet,
        market_id,
        condition_id,
        outcome,
        question,
        investigation_domain,
        market_family_key,
        selection_bucket,
        is_control,
        winning_outcome,
        end_at,
        closed_at,

        MIN(traded_at) AS first_trade_at,

        MIN(traded_at) FILTER (
            WHERE side = 'BUY'
        ) AS first_buy_at,

        MAX(traded_at) AS last_trade_at,
        COUNT(*) AS trade_count,

        SUM(size) FILTER (
            WHERE side = 'BUY'
        ) AS buy_shares,

        SUM(size) FILTER (
            WHERE side = 'SELL'
        ) AS sell_shares,

        SUM(notional_usd) FILTER (
            WHERE side = 'BUY'
        ) AS buy_cost,

        SUM(notional_usd) FILTER (
            WHERE side = 'SELL'
        ) AS sell_proceeds,

        SUM(
            CASE
                WHEN side = 'BUY' THEN size
                WHEN side = 'SELL' THEN -size
                ELSE 0
            END
        ) AS net_shares,

        SUM(notional_usd) AS traded_notional,
        MAX(notional_usd) AS largest_trade_usd,

        CASE
            WHEN SUM(size) FILTER (
                WHERE side = 'BUY'
            ) > 0
            THEN
                SUM(notional_usd) FILTER (
                    WHERE side = 'BUY'
                )
                /
                SUM(size) FILTER (
                    WHERE side = 'BUY'
                )
        END AS average_buy_price
    FROM analysis_trades
    GROUP BY
        proxy_wallet,
        market_id,
        condition_id,
        outcome,
        question,
        investigation_domain,
        market_family_key,
        selection_bucket,
        is_control,
        winning_outcome,
        end_at,
        closed_at
),
wallet_market AS (
    SELECT
        proxy_wallet,
        market_id,
        condition_id,
        question,
        investigation_domain,
        market_family_key,
        selection_bucket,
        is_control,
        winning_outcome,
        end_at,
        closed_at,

        MIN(first_trade_at) AS first_trade_at,

        MIN(first_buy_at) FILTER (
            WHERE outcome = winning_outcome
        ) AS winning_side_first_buy_at,

        MAX(last_trade_at) AS last_trade_at,
        SUM(trade_count) AS trade_count,

        SUM(COALESCE(traded_notional, 0))
            AS total_traded_usd,

        SUM(COALESCE(buy_cost, 0))
            AS total_buy_cost,

        SUM(COALESCE(sell_proceeds, 0))
            AS total_sell_proceeds,

        MAX(largest_trade_usd)
            AS largest_trade_usd,

        SUM(COALESCE(buy_shares, 0)) FILTER (
            WHERE outcome = winning_outcome
        ) AS winning_buy_shares,

        SUM(COALESCE(sell_shares, 0)) FILTER (
            WHERE outcome = winning_outcome
        ) AS winning_sell_shares,

        SUM(COALESCE(buy_cost, 0)) FILTER (
            WHERE outcome = winning_outcome
        ) AS winning_buy_cost,

        SUM(COALESCE(sell_proceeds, 0)) FILTER (
            WHERE outcome = winning_outcome
        ) AS winning_sell_proceeds,

        SUM(
            GREATEST(COALESCE(net_shares, 0), 0)
        ) FILTER (
            WHERE outcome = winning_outcome
        ) AS observed_winning_settlement_shares,

        MIN(average_buy_price) FILTER (
            WHERE outcome = winning_outcome
              AND COALESCE(buy_shares, 0) > 0
        ) AS winning_side_average_entry,

        BOOL_OR(
            COALESCE(sell_shares, 0)
            >
            COALESCE(buy_shares, 0)
        ) AS has_observed_inventory_gap
    FROM outcome_activity
    GROUP BY
        proxy_wallet,
        market_id,
        condition_id,
        question,
        investigation_domain,
        market_family_key,
        selection_bucket,
        is_control,
        winning_outcome,
        end_at,
        closed_at
)
SELECT
    wm.*,

    (
        total_sell_proceeds
        - total_buy_cost
        + COALESCE(
            observed_winning_settlement_shares,
            0
        )
    ) AS observed_settlement_adjusted_pnl,

    CASE
        WHEN total_buy_cost > 0
         AND has_observed_inventory_gap = FALSE
        THEN (
            total_sell_proceeds
            - total_buy_cost
            + COALESCE(
                observed_winning_settlement_shares,
                0
            )
        ) / total_buy_cost
    END AS quality_adjusted_roi,

    (
        COALESCE(winning_buy_shares, 0)
        - COALESCE(winning_buy_cost, 0)
    ) AS gross_winner_purchase_edge,

    CASE
        WHEN total_buy_cost > 0
        THEN COALESCE(winning_buy_cost, 0)
             / total_buy_cost
    END AS winning_buy_cost_share,

    EXTRACT(
        EPOCH FROM (
            COALESCE(closed_at, end_at)
            - winning_side_first_buy_at
        )
    ) / 60 AS winning_entry_minutes_before_close,

    (
        has_observed_inventory_gap = FALSE
        AND (
            total_sell_proceeds
            - total_buy_cost
            + COALESCE(
                observed_winning_settlement_shares,
                0
            )
        ) > 0
    ) AS quality_adjusted_profitable_market,

    (
        winning_side_average_entry IS NOT NULL
        AND winning_side_average_entry < 0.20
        AND COALESCE(winning_buy_cost, 0) >= 100
    ) AS material_low_probability_winner_entry

FROM wallet_market wm;

ALTER TABLE analysis_wallet_market_features
ADD PRIMARY KEY (proxy_wallet, market_id);

CREATE INDEX ix_awmp_wallet
ON analysis_wallet_market_features(proxy_wallet);

CREATE INDEX ix_awmp_market
ON analysis_wallet_market_features(market_id);

CREATE INDEX ix_awmp_winner_buy_time
ON analysis_wallet_market_features(
    winning_side_first_buy_at
);

CREATE INDEX ix_awmp_quality_pnl
ON analysis_wallet_market_features(
    observed_settlement_adjusted_pnl DESC
);

CREATE INDEX ix_awmp_family
ON analysis_wallet_market_features(
    market_family_key
);

ANALYZE analysis_wallet_market_features;
