# Polymarket Insider Trading Investigation

An end-to-end investigation framework for identifying potentially informed trading behaviour on Polymarket using publicly available blockchain and market data.

---

## Live Dashboard

**Interactive Streamlit Dashboard**

**http://32.199.252.119:8501**

The dashboard allows reviewers to explore:

- Investigation dataset summary
- Ranked wallets
- Wallet-level evidence
- Market-level evidence
- Verified public events
- Heuristic scores

---

## Investigation Report

**Methodology & Findings**

https://docs.google.com/document/d/1GtuYEm890atdDKIq2eOP-vAyFU6Nay3x7YwkSecJHMw/edit?usp=sharing

The report explains:

- Investigation methodology
- Market selection
- Public event verification
- Explainable heuristics
- Wallet ranking methodology
- Findings
- Limitations

---

## Investigation Artifacts (CSV)

All CSV outputs used during the investigation are available under:

```
artifacts/submission/csv/
```

Included artifacts:

| File | Description |
|------|-------------|
| 01_market_scope.csv | Final investigation market universe |
| 02_verified_public_events.csv | Public event verification timestamps |
| 03_wallet_ranking.csv | Final wallet insider-likelihood ranking |
| 04_wallet_market_features.csv.gz | Wallet-market feature dataset |

---

# Assessment Objective

The objective of this project is to investigate potential informed trading behaviour on Polymarket between:

**November 1, 2025 – May 1, 2026**

The framework does **not** attempt to prove insider trading.

Instead, it identifies wallets that exhibit multiple behavioural characteristics consistent with potentially informed trading and prioritizes them for further manual investigation.

---

# Investigation Pipeline

```
Polymarket Gamma API
        │
        ▼
Collect Markets
        │
        ▼
Market Normalization
        │
        ▼
Market Family Grouping
        │
        ▼
Representative Market Selection
        │
        ▼
95 Investigation Markets
        │
        ▼
Polymarket Data API
        │
        ▼
Historical Trade Collection
        │
        ▼
Wallet Feature Engineering
        │
        ▼
Explainable Heuristic Scoring
        │
        ▼
Ranked Wallets
```

---

# Dataset Summary

| Metric | Value |
|---------|------:|
| Markets collected | **803,209** |
| Investigation markets | **95** |
| Historical trades collected | **448,711** |
| Unique wallets analysed | **85,537** |
| Wallet-market observations | **467,876** |
| Verified public events | **3** |

---

# Methodology

The investigation consists of five major stages:

1. Collect Polymarket market metadata.
2. Select a representative investigation universe.
3. Collect historical trades.
4. Engineer wallet-level behavioural features.
5. Rank wallets using explainable heuristics.

Markets describing the same real-world event were grouped into **market families**, and the highest-volume representative market from each family was selected to avoid duplicate signals.

---

# Explainable Heuristics

The wallet ranking combines multiple independent behavioural indicators.

- Profitability
- Conviction
- Repeated successful outcomes
- Low-probability winner entries
- Purchases before verified public events
- Domain specialization
- Cross-market consistency
- Control market comparison

No individual heuristic is considered evidence of insider trading.

The final score is intended solely for investigative prioritization.

---

# Repository Structure

```
app/
    dashboard.py

src/
    collectors/
    common/
    exporters/
    normalizers/

sql/

config/

artifacts/
    submission/
        csv/
        report/
        README.md
        HEURISTICS.md
        METHODOLOGY.md
```

---

# Running Locally

Install dependencies:

```bash
pip install -r requirements.txt
```

Launch the dashboard:

```bash
streamlit run app/dashboard.py
```

---

# Technologies

- Python
- PostgreSQL
- SQL
- Streamlit
- Polymarket Gamma API
- Polymarket Data API

---

# Disclaimer

This investigation uses only publicly available blockchain and market data.

A high investigative score should **not** be interpreted as evidence of illegal insider trading.

The ranking framework is designed to prioritize wallets for further manual review using transparent and explainable heuristics.
