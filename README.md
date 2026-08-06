# Polymarket Informed-Trading Investigation

An end-to-end investigation framework for identifying **potentially informed trading behaviour** on Polymarket using publicly available market and trading data.

> **Scores indicate investigative priority only. They do not establish insider trading or unlawful conduct.**

---

# Live Dashboard

### 🌐 Interactive Dashboard

**http://32.199.252.119:8501**

The dashboard allows reviewers to explore:

- Investigation dataset summary
- Ranked wallets
- Wallet drill-down
- Wallet-market evidence
- Market-level evidence
- Verified public-event timing
- Heuristic scores

---

# Investigation Report

### 📄 Methodology & Findings

https://docs.google.com/document/d/1GtuYEm890atdDKIq2eOP-vAyFU6Nay3x7YwkSecJHMw/edit?usp=sharing

The report explains:

- Investigation methodology
- Market universe construction
- Market family selection
- Public-event verification
- Explainable heuristics
- Wallet-ranking methodology
- Findings
- Limitations

---

# Investigation Artifacts (CSV)

### 📁 CSV Outputs

https://github.com/prabuddh1/polymarket-insider-investigation/tree/master/artifacts/submission/csv

Included artifacts:

| File | Description |
|------|-------------|
| 01_market_scope.csv | Final investigation market universe (95 scoped markets) |
| 02_verified_public_events.csv | Verified public-event timestamps and sources |
| 03_wallet_ranking.csv | Final investigative wallet ranking |
| 04_wallet_market_features.csv.gz | Wallet-market evidence dataset |

> **Note:** `04_wallet_market_features.csv.gz` is gzip-compressed because it contains **563,715 wallet-market observations**.

---

# Assessment Objective

The objective of this project is to investigate potential informed trading behaviour on Polymarket between:

**November 1, 2025 – May 1, 2026**

Rather than attempting to prove insider trading, this framework identifies wallets exhibiting multiple behavioural characteristics consistent with potentially informed trading and prioritizes them for further manual investigation.

---

# Investigation Pipeline

```text
Polymarket Gamma API
        │
        ▼
Collect 803,209 Market Records
        │
        ▼
Filter Assessment Period
        │
        ▼
Normalize Markets
        │
        ▼
Group Markets into Families
        │
        ▼
Select Representative Markets
        │
        ▼
95 Scoped Markets
(75 Sensitive + 20 Control)
        │
        ▼
Polymarket Data API
        │
        ▼
Collect Historical Trades
(1,978,986 Trades)
        │
        ▼
Wallet-Market Feature Engineering
(563,715 Wallet-Market Observations)
        │
        ▼
Wallet-Level Behavioural Features
        │
        ▼
Explainable Heuristic Scoring
        │
        ▼
85,537 Ranked Wallets
```

---

# Dataset Summary

| Metric | Value |
|---------|------:|
| Markets collected | **803,209** |
| Scoped investigation markets | **95** |
| Sensitive markets | **75** |
| Control markets | **20** |
| Markets with collected trades | **94** |
| Historical trades collected | **1,978,986** |
| Unique wallets observed | **304,074** |
| Wallet-market observations | **563,715** |
| Ranked wallets | **85,537** |
| Markets with verified public-event timing | **3** |

> One scoped market contained no historical trades during collection.

---

# Methodology

The investigation consists of five major stages:

1. Collect Polymarket market metadata.
2. Build a representative investigation universe.
3. Collect historical trades.
4. Engineer wallet-market and wallet-level behavioural features.
5. Rank wallets using explainable heuristics.

Markets describing the same real-world event (for example, multiple deadline variants) were grouped into **market families**, and a representative market was selected from each family to avoid duplicate signals.

Sports and other externally observable markets were retained as **control markets** for behavioural comparison.

---

# Explainable Investigation Heuristics

| Heuristic | Signal Used | Purpose |
|-----------|-------------|---------|
| Profitability | Quality-adjusted profit in sensitive markets | Prioritizes wallets with consistently profitable trading |
| Conviction | Largest winning-position size | Rewards higher-conviction trades |
| Low-Probability Entries | Purchases of eventual winners at low implied probabilities | Highlights unusually accurate early positioning |
| Repeated Success | Number of profitable sensitive markets | Reduces the impact of one-off successful trades |
| Cross-Family Activity | Number of independent market families traded | Rewards activity across unrelated events |
| Domain Specialization | Concentration within one investigation domain | Captures focused expertise or information advantage |
| Wallet Novelty | Limited history with unusually large positions | Flags potentially purpose-built wallets (low weight) |
| Public-Event Timing | Entry timing relative to verified public disclosures | Strongest indicator of potentially informed trading |
| Control-Market Comparison | Sensitive vs. control-market behaviour | Distinguishes information-driven trading from general trading skill |

Individual heuristic scores are combined into a composite investigative ranking.

No single heuristic is considered evidence of insider trading.

---

# Priority Labels

| Priority | Score |
|----------|------:|
| High Investigative Priority | **80+** |
| Elevated | **65–79** |
| Review | **45–64** |
| Low | **0–44** |

---

# Repository Structure

```text
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

README.md
requirements.txt
requirements-lock.txt
pyproject.toml
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

By default, Streamlit will be available at:

```
http://localhost:8501
```

---

# Technologies

- Python
- PostgreSQL
- SQL
- Streamlit
- Pandas
- Polymarket Gamma API
- Polymarket Data API

---

# Disclaimer

This investigation uses only publicly available market and trading data.

A high investigative score should **not** be interpreted as evidence of illegal insider trading. Observed trading behaviour may result from legitimate research, forecasting skill, public information, or other lawful activity.

The framework is designed solely to prioritize wallets for further manual review using transparent and explainable heuristics.