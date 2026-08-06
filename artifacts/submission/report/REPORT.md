# Insider Trading Detection on Polymarket

# Executive Summary

This investigation analyzes Polymarket markets between **November 1, 2025** and **May 1, 2026** to identify wallets exhibiting characteristics consistent with potentially informed trading.

Rather than attempting to prove insider trading, the analysis prioritizes wallets for further manual investigation using transparent and explainable heuristics.

---

# Dataset Summary

- Markets collected from Polymarket: **803,209**
- Final investigation universe: **95 markets**
- Wallets analyzed: **85,537**
- Wallet-market feature records: **467,877**
- Verified public disclosure events: **3**

---

# Data Collection

A complete market dataset was collected from Polymarket and normalized.

Markets outside the assessment window were excluded.

A representative investigation universe of 95 markets was selected across multiple information-sensitive domains including:

- Geopolitics
- Politics / Macro
- Corporate
- Crypto
- Legal / Regulatory

Sports and reference markets were retained as control groups.

---

# Public Event Verification

Selected disclosure-sensitive markets were manually linked with publicly reported news events using reputable sources.

Verified publication timestamps were incorporated into wallet timing analysis to identify purchases occurring before public disclosure.

---

# Ranking Methodology

Wallets receive an additive investigative score composed of multiple explainable heuristic components:

- profitability
- conviction
- repeated successful outcomes
- specialization
- purchases before verified public events
- successful low-probability outcome purchases
- comparison against control markets

Higher scores indicate stronger priority for manual investigation rather than evidence of misconduct.

---

# Findings

The analysis identified a small number of wallets demonstrating repeated profitable participation across disclosure-sensitive markets together with purchases occurring before verified public events.

These wallets represent candidates for further manual investigation.

The methodology intentionally emphasizes explainability and reproducibility over black-box prediction.

---

# Limitations

The investigation uses only publicly available blockchain and market data.

A high investigative score should **not** be interpreted as proof of illegal insider trading.

Observed behaviour may also result from legitimate research, forecasting skill, or publicly available information.

---

# Conclusion

The submitted framework demonstrates an end-to-end workflow for collecting market data, verifying public events, engineering wallet features, ranking traders using explainable heuristics, and producing reproducible investigation artifacts suitable for further review.
