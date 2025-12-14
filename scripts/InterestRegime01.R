# ============================================================
# 01_data_pull.R
# Purpose: Pull macro + asset proxy time series from FRED
# Author: Richard Anderson
# Repo: macro-regimes-asset-returns
# ============================================================

suppressPackageStartupMessages({
  library(quantmod)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(readr)
})

# -----------------------------
# 0) Configuration
# -----------------------------
# NOTE: Run this script from the project root (recommended)
# e.g., in RStudio: Session -> Set Working Directory -> To Project Directory

PROJECT_DIR <- getwd()

DIRS <- list(
  raw = file.path(PROJECT_DIR, "data", "raw"),
  processed = file.path(PROJECT_DIR, "data", "processed"),
  tables = file.path(PROJECT_DIR, "output", "tables"),
  figures = file.path(PROJECT_DIR, "output", "figures")
)

# Create only the directories we explicitly list above
create_dir_safe <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
}

invisible(lapply(DIRS, create_dir_safe))

# Date window (set wide; analysis scripts can filter later)
START_DATE <- as.Date("1990-01-01")
END_DATE   <- Sys.Date()

# -----------------------------
# 1) Series selection (FRED)
# -----------------------------
# Macro / policy:
# - EFFR: Effective Federal Funds Rate (daily)
# - CPIAUCSL: CPI (monthly; index level)
#
# Asset proxies (we will compute returns later in Script 03):
# - SP500: S&P 500 index level (daily)
# - DGS10: 10-Year Treasury Constant Maturity Rate (daily yield, %)
# - TB3MS: 3-Month Treasury Bill Secondary Market Rate (monthly yield, %)
#
# Note: Total return indices for bonds/equities can be added later if desired.
# This initial version uses widely available, defensible proxies from FRED.

SERIES <- c(
  "EFFR",       # Effective Federal Funds Rate (daily)
  "CPIAUCSL",   # CPI (monthly)
  "SP500",      # S&P 500 (daily index level)
  "DGS10",      # 10Y Treasury yield (daily)
  "TB3MS"       # 3M T-bill rate (monthly)
)

# -----------------------------
# 2) Pull from FRED (quantmod)
# -----------------------------
pull_fred_series <- function(symbol) {
  message("Pulling: ", symbol)
  out <- tryCatch(
    {
      getSymbols(
        Symbols = symbol,
        src = "FRED",
        from = START_DATE,
        to = END_DATE,
        auto.assign = FALSE
      )
    },
    error = function(e) {
      warning("Failed to pull ", symbol, ": ", conditionMessage(e))
      return(NULL)
    }
  )
  out
}

series_list <- lapply(SERIES, pull_fred_series)
names(series_list) <- SERIES

# Drop any NULLs if a pull failed
series_list <- series_list[!vapply(series_list, is.null, logical(1))]

if (length(series_list) == 0) {
  stop("No series were successfully pulled. Check internet access / FRED availability.")
}

# -----------------------------
# 3) Standardize to a single long table
# -----------------------------
# Convert each xts series into a tibble: date, value, series
xts_to_long_tbl <- function(x, series_name) {
  tibble(
    date = as.Date(index(x)),
    value = as.numeric(coredata(x)[, 1]),
    series = series_name
  )
}

long_tbl <- bind_rows(
  lapply(names(series_list), function(nm) xts_to_long_tbl(series_list[[nm]], nm))
) %>%
  arrange(series, date)

# Save raw long table (this is your "source of truth" for pulled data)
raw_rds_path <- file.path(DIRS$raw, "fred_series_long_raw.rds")
raw_csv_path <- file.path(DIRS$raw, "fred_series_long_raw.csv")

saveRDS(long_tbl, raw_rds_path)
write_csv(long_tbl, raw_csv_path)

message("Saved raw outputs:")
message(" - ", raw_rds_path)
message(" - ", raw_csv_path)

# -----------------------------
# 4) Create a wide monthly panel (processed)
# -----------------------------
# For regime classification and cross-asset comparisons, a monthly panel is cleaner.
# We convert daily series to monthly by taking month-end observation.
# CPIAUCSL and TB3MS are already monthly (but may have month-start dates).

long_tbl_monthly <- long_tbl %>%
  mutate(month = floor_date(date, unit = "month")) %>%
  group_by(series, month) %>%
  summarise(
    # Month-end observation (last non-NA within month)
    value = dplyr::last(value[!is.na(value)]),
    .groups = "drop"
  ) %>%
  rename(date = month)

wide_monthly <- long_tbl_monthly %>%
  tidyr::pivot_wider(names_from = series, values_from = value) %>%
  arrange(date)

processed_rds_path <- file.path(DIRS$processed, "macro_asset_monthly_panel.rds")
processed_csv_path <- file.path(DIRS$processed, "macro_asset_monthly_panel.csv")

saveRDS(wide_monthly, processed_rds_path)
write_csv(wide_monthly, processed_csv_path)

message("Saved processed outputs:")
message(" - ", processed_rds_path)
message(" - ", processed_csv_path)

# -----------------------------
# 5) Basic QA checks (lightweight)
# -----------------------------
qa_summary <- wide_monthly %>%
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    n_months = n(),
    missing_EFFR = sum(is.na(EFFR)),
    missing_CPIAUCSL = sum(is.na(CPIAUCSL)),
    missing_SP500 = sum(is.na(SP500)),
    missing_DGS10 = sum(is.na(DGS10)),
    missing_TB3MS = sum(is.na(TB3MS))
  )

qa_path <- file.path(DIRS$tables, "qa_monthly_panel_summary.csv")
write_csv(qa_summary, qa_path)

message("Saved QA summary:")
message(" - ", qa_path)

message("01_data_pull.R complete.")
