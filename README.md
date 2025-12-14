# macro-regimes-asset-returns
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Language: R](https://img.shields.io/badge/Language-R-blue.svg)
![Data: FRED](https://img.shields.io/badge/Data-FRED-lightgrey.svg)

## Overview
This project presents an empirical macro-finance analysis examining how U.S. interest-rate and inflation regimes relate to equity and fixed-income asset behavior. Rather than relying on narrative or political classifications, macroeconomic regimes are defined quantitatively using historical Federal Reserve data.

The primary objective is to evaluate whether equity performance differs meaningfully across rising, falling, and stable interest-rate environments, and to assess the extent to which these differences are economically and statistically meaningful.

---

## Data
Macroeconomic and financial time series were retrieved programmatically from the Federal Reserve Economic Data (FRED) database using reproducible R workflows.

**Key series include:**
- Effective Federal Funds Rate (EFFR)
- Consumer Price Index (CPIAUCSL)
- S&P 500 price index (SP500)
- 10-Year Treasury yield (DGS10)
- 3-Month Treasury Bill rate (TB3MS)

**Data coverage:** approximately 1990–2024  
**Frequency:** monthly (aggregated from daily where applicable)

---

## Methodology
- Daily and monthly series were aligned to a common monthly frequency  
- Inflation was computed as year-over-year CPI growth  
- Interest-rate direction regimes were classified using 12-month changes in the federal funds rate  
- Rate-level and inflation regimes were defined using historical percentiles  
- Monthly equity returns were computed using log returns of the S&P 500 price index  
- Regime-based comparisons were conducted using summary statistics and two-sample tests  

The analysis emphasizes economic magnitude and interpretability, recognizing the inherent noise and serial dependence present in macroeconomic financial time series.

---

## Key Findings
- Equity returns were highest during falling interest-rate regimes and lowest during rising-rate regimes  
- Differences in average returns were economically meaningful but statistically noisy  
- Results are consistent with established macro-finance theory regarding discount rates and monetary policy transmission  

---

## Visual Summary

### Regimes and equity performance over time
![S&P 500 cumulative with regime shading](output/figures/fig02_sp500_cumulative_with_regime_shading.png)

### Distribution of monthly equity returns by regime
![S&P 500 returns boxplot by regime](output/figures/fig03_sp500_returns_boxplot_by_regime.png)

---

## Repository Structure
```
macro-regimes-asset-returns/
├── data/
│   ├── raw/
│   └── processed/
├── scripts/
│   ├── 01_data_pull.R
│   ├── 02_regime_classification.R
│   ├── 03_return_analysis.R
│   └── 04_visualizations.R
├── output/
│   ├── tables/
│   └── figures/
├── report/
│   └── macro_regimes_analysis.Rmd
├── README.md
└── LICENSE
```

---

## Reproducibility
All results in this repository are reproducible. Scripts should be run sequentially (`01` → `04`) from the project root. No manual data downloads are required.

---

## Notes
- The S&P 500 series used is a **price index** and does not include dividends.  
- Bond behavior is proxied using changes in Treasury yields rather than total return indices.  
- This project was conducted as an independent research study for portfolio and skill development purposes.  

---

## Tools
R, quantmod, tidyverse, ggplot2, time-series analysis
