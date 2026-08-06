from __future__ import annotations

from pathlib import Path

import pandas as pd
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = PROJECT_ROOT / "artifacts" / "submission" / "csv"

MARKET_SCOPE_PATH = CSV_DIR / "01_market_scope.csv"
EVENTS_PATH = CSV_DIR / "02_verified_public_events.csv"
RANKINGS_PATH = CSV_DIR / "03_wallet_ranking.csv"
FEATURES_PATH = CSV_DIR / "04_wallet_market_features.csv.gz"


st.set_page_config(
    page_title="Polymarket Informed-Trading Investigation",
    page_icon="🔎",
    layout="wide",
)


@st.cache_data(show_spinner="Loading market scope...")
def load_market_scope() -> pd.DataFrame:
    return pd.read_csv(MARKET_SCOPE_PATH)


@st.cache_data(show_spinner="Loading verified events...")
def load_events() -> pd.DataFrame:
    return pd.read_csv(EVENTS_PATH)


@st.cache_data(show_spinner="Loading wallet rankings...")
def load_rankings() -> pd.DataFrame:
    df = pd.read_csv(RANKINGS_PATH)

    numeric_columns = [
        "total_score",
        "markets_traded",
        "families_traded",
        "domains_traded",
        "sensitive_markets_traded",
        "control_markets_traded",
        "sensitive_quality_adjusted_pnl",
        "sensitive_quality_win_rate",
        "verified_pre_event_markets",
        "public_event_timing_score",
        "repeated_success_score",
        "conviction_score",
        "specialization_score",
    ]

    for column in numeric_columns:
        if column in df.columns:
            df[column] = pd.to_numeric(
                df[column],
                errors="coerce",
            )

    return df.sort_values(
        ["total_score", "sensitive_quality_adjusted_pnl"],
        ascending=[False, False],
        na_position="last",
    ).reset_index(drop=True)


@st.cache_data(show_spinner="Loading wallet-market evidence...")
def load_features() -> pd.DataFrame:
    df = pd.read_csv(FEATURES_PATH, compression="gzip")

    numeric_columns = [
        "winner_entry_minutes_before_event",
        "trade_count",
        "winning_buy_cost",
        "observed_settlement_adjusted_pnl",
        "quality_adjusted_roi",
        "gross_winner_purchase_edge",
    ]

    for column in numeric_columns:
        if column in df.columns:
            df[column] = pd.to_numeric(
                df[column],
                errors="coerce",
            )

    datetime_columns = [
        "winning_side_first_buy_at",
        "public_event_time",
    ]

    for column in datetime_columns:
        if column in df.columns:
            df[column] = pd.to_datetime(
                df[column],
                errors="coerce",
                utc=True,
            )

    boolean_columns = [
        "material_low_probability_winner_entry",
        "quality_adjusted_profitable_market",
        "has_observed_inventory_gap",
    ]

    boolean_map = {
        True: True,
        False: False,
        "t": True,
        "f": False,
        "true": True,
        "false": False,
        "True": True,
        "False": False,
        "1": True,
        "0": False,
        1: True,
        0: False,
    }

    for column in boolean_columns:
        if column in df.columns:
            df[column] = (
                df[column]
                .map(boolean_map)
                .fillna(False)
                .astype(bool)
            )

    return df


def short_wallet(wallet: str) -> str:
    if not isinstance(wallet, str) or len(wallet) < 16:
        return str(wallet)

    return f"{wallet[:8]}…{wallet[-6:]}"


market_scope = load_market_scope()
events = load_events()
rankings = load_rankings()


st.title("Polymarket Informed-Trading Investigation")

st.caption(
    "An explainable investigative-priority framework using public "
    "Polymarket data. Scores indicate review priority, not proof of misconduct."
)


overview_tab, ranking_tab, wallet_tab, evidence_tab = st.tabs(
    [
        "Overview",
        "Wallet Rankings",
        "Wallet Drill-Down",
        "Market Evidence",
    ]
)


with overview_tab:
    high_priority_count = int(
        (
            rankings["priority_label"]
            == "HIGH_INVESTIGATIVE_PRIORITY"
        ).sum()
    )

    elevated_count = int(
        (rankings["priority_label"] == "ELEVATED").sum()
    )

    timed_wallet_count = int(
        rankings["timing_evidence_available"]
        .fillna(False)
        .astype(bool)
        .sum()
    )

    col1, col2, col3, col4, col5 = st.columns(5)

    col1.metric("Scoped Markets", f"{len(market_scope):,}")
    col2.metric("Ranked Wallets", f"{len(rankings):,}")
    col3.metric("Verified Events", f"{len(events):,}")
    col4.metric("High / Elevated", high_priority_count + elevated_count)
    col5.metric("Timing Evidence", f"{timed_wallet_count:,}")

    st.subheader("Score Distribution")

    score_distribution = (
        rankings["total_score"]
        .value_counts()
        .sort_index()
        .rename_axis("Score")
        .to_frame("Wallets")
    )

    st.bar_chart(score_distribution)

    left, right = st.columns(2)

    with left:
        st.subheader("Investigation Domains")

        domain_counts = (
            market_scope["investigation_domain"]
            .value_counts()
            .rename_axis("Domain")
            .to_frame("Markets")
        )

        st.bar_chart(domain_counts)

    with right:
        st.subheader("Priority Labels")

        priority_counts = (
            rankings["priority_label"]
            .value_counts()
            .rename_axis("Priority")
            .to_frame("Wallets")
        )

        st.bar_chart(priority_counts)

    st.subheader("Verified Public Events")

    event_columns = [
        column
        for column in [
            "market_id",
            "market_family_key",
            "public_event_time",
            "headline",
            "source_name",
            "timestamp_confidence",
            "timing_method",
        ]
        if column in events.columns
    ]

    st.dataframe(
        events[event_columns],
        width="stretch",
        hide_index=True,
    )


with ranking_tab:
    st.subheader("Wallet Ranking")

    filter_col1, filter_col2, filter_col3 = st.columns(3)

    priority_options = sorted(
        rankings["priority_label"]
        .dropna()
        .unique()
        .tolist()
    )

    selected_priorities = filter_col1.multiselect(
        "Priority",
        priority_options,
        default=priority_options,
    )

    minimum_score = filter_col2.slider(
        "Minimum score",
        min_value=int(rankings["total_score"].min()),
        max_value=int(rankings["total_score"].max()),
        value=0,
    )

    maximum_rows = filter_col3.slider(
        "Rows to show",
        min_value=10,
        max_value=500,
        value=100,
        step=10,
    )

    filtered_rankings = rankings[
        rankings["priority_label"].isin(selected_priorities)
        & (rankings["total_score"] >= minimum_score)
    ].head(maximum_rows).copy()

    filtered_rankings.insert(
        0,
        "rank",
        range(1, len(filtered_rankings) + 1),
    )

    filtered_rankings["wallet_short"] = (
        filtered_rankings["proxy_wallet"].map(short_wallet)
    )

    display_columns = [
        "rank",
        "wallet_short",
        "total_score",
        "priority_label",
        "sensitive_markets_traded",
        "families_traded",
        "sensitive_quality_adjusted_pnl",
        "sensitive_quality_win_rate",
        "verified_pre_event_markets",
        "public_event_timing_score",
        "repeated_success_score",
        "conviction_score",
        "specialization_score",
    ]

    st.dataframe(
        filtered_rankings[display_columns],
        width="stretch",
        hide_index=True,
        column_config={
            "sensitive_quality_adjusted_pnl": st.column_config.NumberColumn(
                "Estimated sensitive PnL",
                format="$%.2f",
            ),
            "sensitive_quality_win_rate": st.column_config.NumberColumn(
                "Sensitive win rate",
                format="%.2f",
            ),
        },
    )

    st.download_button(
        "Download filtered ranking",
        data=filtered_rankings.to_csv(index=False),
        file_name="filtered_wallet_ranking.csv",
        mime="text/csv",
    )


with wallet_tab:
    st.subheader("Wallet Drill-Down")

    top_wallet_options = rankings.head(500)["proxy_wallet"].tolist()

    selected_wallet = st.selectbox(
        "Select a top-ranked wallet",
        top_wallet_options,
        format_func=short_wallet,
    )

    wallet_row = rankings[
        rankings["proxy_wallet"] == selected_wallet
    ].iloc[0]

    metric1, metric2, metric3, metric4, metric5 = st.columns(5)

    metric1.metric(
        "Total Score",
        int(wallet_row["total_score"]),
    )

    metric2.metric(
        "Priority",
        str(wallet_row["priority_label"]),
    )

    metric3.metric(
        "Sensitive Markets",
        int(wallet_row["sensitive_markets_traded"]),
    )

    pnl_value = wallet_row.get(
        "sensitive_quality_adjusted_pnl",
        float("nan"),
    )

    metric4.metric(
        "Estimated Sensitive PnL",
        f"${pnl_value:,.2f}" if pd.notna(pnl_value) else "N/A",
    )

    metric5.metric(
        "Timing Score",
        int(wallet_row["public_event_timing_score"]),
    )

    st.code(selected_wallet)

    with st.spinner("Loading wallet evidence..."):
        features = load_features()

    wallet_features = features[
        features["proxy_wallet"] == selected_wallet
    ].copy()

    if wallet_features.empty:
        st.warning("No wallet-market evidence found for this wallet.")
    else:
        st.subheader("Wallet-Market Evidence")

        evidence_columns = [
            "market_id",
            "question",
            "investigation_domain",
            "winning_outcome",
            "winning_side_first_buy_at",
            "public_event_time",
            "winner_entry_minutes_before_event",
            "winning_buy_cost",
            "observed_settlement_adjusted_pnl",
            "quality_adjusted_roi",
            "gross_winner_purchase_edge",
            "material_low_probability_winner_entry",
            "quality_adjusted_profitable_market",
            "has_observed_inventory_gap",
            "public_event_source",
            "public_event_confidence",
        ]

        wallet_features = wallet_features.sort_values(
            "observed_settlement_adjusted_pnl",
            ascending=False,
            na_position="last",
        )

        st.dataframe(
            wallet_features[evidence_columns],
            width="stretch",
            hide_index=True,
            column_config={
                "winning_buy_cost": st.column_config.NumberColumn(
                    "Winning buy cost",
                    format="$%.2f",
                ),
                "observed_settlement_adjusted_pnl": (
                    st.column_config.NumberColumn(
                        "Estimated PnL",
                        format="$%.2f",
                    )
                ),
                "quality_adjusted_roi": st.column_config.NumberColumn(
                    "Quality-adjusted ROI",
                    format="%.3f",
                ),
                "winner_entry_minutes_before_event": (
                    st.column_config.NumberColumn(
                        "Minutes before event",
                        format="%.2f",
                    )
                ),
            },
        )

        chart_data = wallet_features[
            [
                "question",
                "observed_settlement_adjusted_pnl",
            ]
        ].dropna()

        if not chart_data.empty:
            chart_data = (
                chart_data.groupby("question")[
                    "observed_settlement_adjusted_pnl"
                ]
                .sum()
                .sort_values(ascending=False)
                .head(15)
            )

            st.subheader("Estimated PnL by Market")
            st.bar_chart(chart_data)

        st.download_button(
            "Download wallet evidence",
            data=wallet_features.to_csv(index=False),
            file_name=f"{selected_wallet}_evidence.csv",
            mime="text/csv",
        )


with evidence_tab:
    st.subheader("Market-Level Evidence Explorer")

    with st.spinner("Loading evidence dataset..."):
        features = load_features()

    domains = sorted(
        features["investigation_domain"]
        .dropna()
        .unique()
        .tolist()
    )

    selected_domain = st.selectbox(
        "Investigation domain",
        ["All"] + domains,
    )

    evidence_filter1, evidence_filter2 = st.columns(2)

    low_probability_only = evidence_filter1.checkbox(
        "Material low-probability winner entries only"
    )

    timing_only = evidence_filter2.checkbox(
        "Verified pre-event entries only"
    )

    evidence_view = features.copy()

    if selected_domain != "All":
        evidence_view = evidence_view[
            evidence_view["investigation_domain"]
            == selected_domain
        ]

    if low_probability_only:
        evidence_view = evidence_view.loc[
            evidence_view[
                "material_low_probability_winner_entry"
            ].fillna(False).astype(bool)
        ]

    if timing_only:
        evidence_view = evidence_view[
            evidence_view[
                "winner_entry_minutes_before_event"
            ].fillna(-1)
            > 0
        ]

    evidence_view = evidence_view.sort_values(
        "observed_settlement_adjusted_pnl",
        ascending=False,
        na_position="last",
    ).head(1000)

    evidence_columns = [
        "proxy_wallet",
        "market_id",
        "question",
        "investigation_domain",
        "winning_outcome",
        "winner_entry_minutes_before_event",
        "winning_buy_cost",
        "observed_settlement_adjusted_pnl",
        "quality_adjusted_roi",
        "gross_winner_purchase_edge",
        "material_low_probability_winner_entry",
        "has_observed_inventory_gap",
        "public_event_source",
    ]

    st.dataframe(
        evidence_view[evidence_columns],
        width="stretch",
        hide_index=True,
        column_config={
            "winning_buy_cost": st.column_config.NumberColumn(
                "Winning buy cost",
                format="$%.2f",
            ),
            "observed_settlement_adjusted_pnl": (
                st.column_config.NumberColumn(
                    "Estimated PnL",
                    format="$%.2f",
                )
            ),
        },
    )

    st.download_button(
        "Download current evidence view",
        data=evidence_view.to_csv(index=False),
        file_name="market_evidence_view.csv",
        mime="text/csv",
    )


st.divider()

st.caption(
    "Important: A high investigative score indicates stronger observable "
    "signals warranting review. It does not establish unlawful conduct."
)
