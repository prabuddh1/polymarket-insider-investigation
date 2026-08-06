# Methodology

## Dataset

Markets were collected from Polymarket and restricted to the assessment window:

2025-11-01 through 2026-05-01.

## Market Selection

Markets were classified into investigation domains including:

- Corporate
- Crypto
- Politics
- Geopolitics
- Legal / Regulatory

Reference and sports markets were retained as control groups.

The final investigation universe contained 95 representative markets.

## Trade Collection

Trades were collected from the Polymarket Data API.

Collection automatically handled dense markets by recursively splitting time windows until all available trades were retrieved.

## Public Event Verification

Selected disclosure-sensitive markets were manually linked to publicly reported events using reputable news sources.

Verified timestamps were incorporated into wallet timing analysis.

## Feature Engineering

Wallet-level features included:

- profitability
- trade timing
- concentration
- repeated success
- domain specialization
- conviction
- quality-adjusted PnL

## Ranking

Each wallet received a composite score derived from explainable heuristic components.

Higher scores indicate stronger evidence for further manual investigation rather than proof of misconduct.
