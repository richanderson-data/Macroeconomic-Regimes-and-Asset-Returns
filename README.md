# Macroeconomic Regimes and Asset Returns

## Overview
This project presents an empirical macro-finance analysis examining how U.S. interest-rate and inflation regimes relate to equity and fixed-income asset behavior. Rather than relying on narrative or political classifications, regimes are defined quantitatively using historical Federal Reserve data.

The analysis focuses on whether equity performance differs meaningfully across rising, falling, and stable interest-rate environments, and how inflation regimes interact with these dynamics.

## Data
All macroeconomic and financial time series were retrieved programmatically from the Federal Reserve Economic Data (FRED) database using reproducible R workflows.

**Primary series include:**
- Effective Federal Funds Rate (EFFR)
- Consumer Price Index (CPIAUCSL)
- S&P 500 price index (SP500)
- 10-Year Treasury yield (DGS10)
- 3-Month Treasury Bill rate (TB3MS)

**Data coverage:** approximately 1990–2024 (monthly aggregation)

## Methods
- Daily and monthly series were aligned to a monthly frequency using month-end observations
- Inflation was computed as year-over-year CPI growth
- Interest-rate regimes were classified using 12-month changes in the federal funds rate
- Rate level and inflation regimes were defined using historical percentiles
- Monthly equity returns were computed using log returns
- Regime-based comparisons were conducted using summary statistics and two-sample tests

## Key Findings
Equity returns were highest during falling interest-rate regimes and lowest during rising-rate regimes. While the magnitude of the return differences was economically meaningful, statistical significance was limited, reflecting the inherent noise and serial dependence in macroeconomic time series.

These findings are consistent with established macro-finance theory and highlight the challenges of isolating regime effects in real-world financial data.

## Tools
R, quantmod, tidyverse, regression modeling, time-series analysis

## Notes
This project was conducted as an independent research study for portfolio and skill development purposes. All results are reproducible using the provided scripts.
