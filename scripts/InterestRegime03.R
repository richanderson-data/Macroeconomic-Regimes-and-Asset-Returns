# ============================================================
# 03_return_analysis.R
# Purpose: Compute monthly returns and summarize by regimes
# Inputs:  data/processed/macro_asset_monthly_with_regimes.{csv|rds}
# Outputs: data/processed/asset_returns_with_regimes.{csv|rds}
#          output/tables/returns_summary_by_regime.csv
#          output/tables/returns_summary_by_joint_regime.csv
#          output/tables/t_test_equity_rising_vs_falling.csv
# ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(lubridate)
  library(stringr)
})

# -----------------------------
# 0) Paths
# -----------------------------
PROJECT_DIR <- getwd()

DIRS <- list(
  processed = file.path(PROJECT_DIR, "data", "processed"),
  tables = file.path(PROJECT_DIR, "output", "tables"),
  figures = file.path(PROJECT_DIR, "output", "figures")
)

create_dir_safe <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
invisible(lapply(DIRS, create_dir_safe))

in_path_rds <- file.path(DIRS$processed, "macro_asset_monthly_with_regimes.rds")
in_path_csv <- file.path(DIRS$processed, "macro_asset_monthly_with_regimes.csv")

df <- if (file.exists(in_path_rds)) {
  readRDS(in_path_rds)
} else if (file.exists(in_path_csv)) {
  read_csv(in_path_csv, show_col_types = FALSE)
} else {
  stop("Cannot find macro_asset_monthly_with_regimes.{rds|csv}. Run Script 02 first.")
}

df <- df %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

# -----------------------------
# 1) Helper functions
# -----------------------------
# Safe log return: returns NA if current or previous is missing/non-positive
log_return <- function(x) {
  dplyr::if_else(!is.na(x) & !is.na(dplyr::lag(x)) & x > 0 & dplyr::lag(x) > 0,
                 log(x / dplyr::lag(x)),
                 NA_real_)
}

# Convert annualized percent yield to monthly simple return approximation:
# r_month ≈ (yield/100) / 12
yield_to_monthly_simple <- function(y) {
  dplyr::if_else(!is.na(y), (y / 100) / 12, NA_real_)
}

# Summary stats for a return vector (in decimals)
return_stats <- function(r) {
  r2 <- r[!is.na(r)]
  tibble(
    n = length(r2),
    mean = if (length(r2) > 1) mean(r2) else NA_real_,
    sd = if (length(r2) > 1) stats::sd(r2) else NA_real_,
    annualized_mean = if (length(r2) > 1) mean(r2) * 12 else NA_real_,
    annualized_sd = if (length(r2) > 1) stats::sd(r2) * sqrt(12) else NA_real_
  )
}

# -----------------------------
# 2) Compute asset returns (monthly)
# -----------------------------
# Equity: SP500 log return (price index)
# Cash: TB3MS monthly simple return approximation
# Bonds (proxy): Use DGS10 yield changes as a *rate-risk proxy* (not total return)
#   - For now we compute monthly change in 10Y yield (percentage points) as a risk factor.
#   - Later, we can upgrade to an actual bond total return index if you want.
df_ret <- df %>%
  mutate(
    # Equity monthly log return (decimal)
    ret_sp500_log = log_return(SP500),
    
    # Cash monthly simple return approximation (decimal)
    ret_tb3m_simple = yield_to_monthly_simple(TB3MS),
    
    # 10Y yield change (percentage points, not a return)
    d_dgs10_pp = if_else(!is.na(DGS10) & !is.na(lag(DGS10)),
                         DGS10 - lag(DGS10),
                         NA_real_)
  )

# Create a “usable” analysis frame where regimes exist
df_ret <- df_ret %>%
  mutate(
    has_core_regimes = !is.na(rate_direction_regime) & !is.na(inflation_regime),
    has_equity_return = !is.na(ret_sp500_log),
    has_cash_return = !is.na(ret_tb3m_simple)
  )

# Save the return-enriched dataset
out_rds <- file.path(DIRS$processed, "asset_returns_with_regimes.rds")
out_csv <- file.path(DIRS$processed, "asset_returns_with_regimes.csv")
saveRDS(df_ret, out_rds)
write_csv(df_ret, out_csv)

# -----------------------------
# 3) Summary by individual regimes
# -----------------------------
# Equity returns by rate direction
equity_by_rate_dir <- df_ret %>%
  filter(has_core_regimes) %>%
  group_by(rate_direction_regime) %>%
  summarise(return_stats(ret_sp500_log), .groups = "drop") %>%
  mutate(asset = "SP500 (log return)", regime_type = "rate_direction_regime") %>%
  relocate(asset, regime_type, rate_direction_regime)

# Equity returns by inflation regime
equity_by_infl <- df_ret %>%
  filter(has_core_regimes) %>%
  group_by(inflation_regime) %>%
  summarise(return_stats(ret_sp500_log), .groups = "drop") %>%
  mutate(asset = "SP500 (log return)", regime_type = "inflation_regime") %>%
  relocate(asset, regime_type, inflation_regime)

# Cash returns by rate direction
cash_by_rate_dir <- df_ret %>%
  filter(has_core_regimes) %>%
  group_by(rate_direction_regime) %>%
  summarise(return_stats(ret_tb3m_simple), .groups = "drop") %>%
  mutate(asset = "3M T-Bill (simple approx)", regime_type = "rate_direction_regime") %>%
  relocate(asset, regime_type, rate_direction_regime)

# “Bond risk proxy” by rate direction (mean change in 10Y yields)
dgs10_by_rate_dir <- df_ret %>%
  filter(has_core_regimes) %>%
  group_by(rate_direction_regime) %>%
  summarise(
    n = sum(!is.na(d_dgs10_pp)),
    mean_change_pp = mean(d_dgs10_pp, na.rm = TRUE),
    sd_change_pp = stats::sd(d_dgs10_pp, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(asset = "10Y Yield (Δ pp)", regime_type = "rate_direction_regime") %>%
  relocate(asset, regime_type, rate_direction_regime)

returns_summary <- bind_rows(
  equity_by_rate_dir,
  equity_by_infl,
  cash_by_rate_dir
)

out_summary <- file.path(DIRS$tables, "returns_summary_by_regime.csv")
write_csv(returns_summary, out_summary)

out_bond_proxy <- file.path(DIRS$tables, "dgs10_change_by_rate_direction.csv")
write_csv(dgs10_by_rate_dir, out_bond_proxy)

# -----------------------------
# 4) Summary by joint regime
# -----------------------------
joint_summary <- df_ret %>%
  filter(!is.na(joint_regime)) %>%
  group_by(joint_regime) %>%
  summarise(return_stats(ret_sp500_log), .groups = "drop") %>%
  arrange(desc(n))

out_joint <- file.path(DIRS$tables, "returns_summary_by_joint_regime.csv")
write_csv(joint_summary, out_joint)

# -----------------------------
# 5) Simple significance test (equity): Rising vs Falling
# -----------------------------
# This is a basic two-sample t-test on monthly equity returns.
# We keep it simple; we can add HAC / Newey-West later if needed.
tt_data <- df_ret %>%
  filter(rate_direction_regime %in% c("Rising", "Falling")) %>%
  select(rate_direction_regime, ret_sp500_log) %>%
  filter(!is.na(ret_sp500_log))

if (nrow(tt_data) >= 30 && length(unique(tt_data$rate_direction_regime)) == 2) {
  t_out <- t.test(ret_sp500_log ~ rate_direction_regime, data = tt_data)
  
  t_tbl <- tibble(
    group1 = "Rising",
    group2 = "Falling",
    mean_rising = mean(tt_data$ret_sp500_log[tt_data$rate_direction_regime == "Rising"], na.rm = TRUE),
    mean_falling = mean(tt_data$ret_sp500_log[tt_data$rate_direction_regime == "Falling"], na.rm = TRUE),
    diff_mean = mean_rising - mean_falling,
    t_stat = as.numeric(t_out$statistic),
    p_value = as.numeric(t_out$p.value),
    conf_low = as.numeric(t_out$conf.int[1]),
    conf_high = as.numeric(t_out$conf.int[2]),
    n_rising = sum(tt_data$rate_direction_regime == "Rising"),
    n_falling = sum(tt_data$rate_direction_regime == "Falling")
  )
  
  out_ttest <- file.path(DIRS$tables, "t_test_equity_rising_vs_falling.csv")
  write_csv(t_tbl, out_ttest)
} else {
  warning("Not enough data for t-test or missing both regimes.")
}

message("Saved outputs:")
message(" - ", out_rds)
message(" - ", out_csv)
message(" - ", out_summary)
message(" - ", out_bond_proxy)
message(" - ", out_joint)
message("03_return_analysis.R complete.")

