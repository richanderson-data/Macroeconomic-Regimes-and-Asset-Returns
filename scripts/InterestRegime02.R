# ============================================================
# 02_regime_classification.R
# Purpose: Classify interest-rate and inflation regimes
# Inputs:  data/processed/macro_asset_monthly_panel.{csv|rds}
# Outputs: data/processed/macro_asset_monthly_with_regimes.{csv|rds}
#          output/tables/regime_counts.csv
#          output/tables/regime_thresholds.csv
# ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
  library(tidyr)
})

# -----------------------------
# 0) Paths + directory safety
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

in_path_rds <- file.path(DIRS$processed, "macro_asset_monthly_panel.rds")
in_path_csv <- file.path(DIRS$processed, "macro_asset_monthly_panel.csv")

# Prefer RDS if available (keeps types clean)
df <- if (file.exists(in_path_rds)) {
  readRDS(in_path_rds)
} else if (file.exists(in_path_csv)) {
  read_csv(in_path_csv, show_col_types = FALSE)
} else {
  stop("Cannot find macro_asset_monthly_panel.{rds|csv} in data/processed/. Run Script 01 first.")
}

# Basic validation
required_cols <- c("date", "EFFR", "CPIAUCSL")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}

df <- df %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

# -----------------------------
# 1) Helper functions
# -----------------------------
# Safe quantile: returns NA if too few non-missing values
safe_quantile <- function(x, probs) {
  x2 <- x[!is.na(x)]
  if (length(x2) < 24) { # require at least 2 years of monthly data
    return(rep(NA_real_, length(probs)))
  }
  as.numeric(stats::quantile(x2, probs = probs, na.rm = TRUE, type = 7))
}

# -----------------------------
# 2) Compute core derived series
# -----------------------------
# Inflation YoY based on CPI index level:
# inflation_yoy = (CPI_t / CPI_{t-12} - 1) * 100
df2 <- df %>%
  mutate(
    cpi_lag12 = dplyr::lag(CPIAUCSL, 12),
    inflation_yoy = if_else(
      !is.na(CPIAUCSL) & !is.na(cpi_lag12) & cpi_lag12 > 0,
      (CPIAUCSL / cpi_lag12 - 1) * 100,
      NA_real_
    )
  ) %>%
  select(-cpi_lag12)

# 12-month change in EFFR (percentage points):
# d12_effr = EFFR_t - EFFR_{t-12}
df2 <- df2 %>%
  mutate(
    effr_lag12 = dplyr::lag(EFFR, 12),
    d12_effr_pp = if_else(
      !is.na(EFFR) & !is.na(effr_lag12),
      (EFFR - effr_lag12),
      NA_real_
    )
  ) %>%
  select(-effr_lag12)

# -----------------------------
# 3) Thresholds (percentiles) for regimes
# -----------------------------
# Rate level thresholds from EFFR distribution
effr_q <- safe_quantile(df2$EFFR, c(0.25, 0.75))
effr_p25 <- effr_q[1]
effr_p75 <- effr_q[2]

# Inflation thresholds from inflation_yoy distribution
infl_q <- safe_quantile(df2$inflation_yoy, c(0.25, 0.75))
infl_p25 <- infl_q[1]
infl_p75 <- infl_q[2]

# Direction threshold (fixed, interpretable)
DIRECTION_THRESHOLD_PP <- 0.25

thresholds_tbl <- tibble(
  metric = c("EFFR_level", "Inflation_YoY", "EFFR_12m_change_pp"),
  p25 = c(effr_p25, infl_p25, NA_real_),
  p75 = c(effr_p75, infl_p75, NA_real_),
  threshold = c(NA_real_, NA_real_, DIRECTION_THRESHOLD_PP),
  notes = c(
    "Rate level regime thresholds based on EFFR percentiles",
    "Inflation regime thresholds based on CPI YoY percentiles",
    "Direction regime uses +/- threshold on 12m change in EFFR"
  )
)

out_thresholds <- file.path(DIRS$tables, "regime_thresholds.csv")
write_csv(thresholds_tbl, out_thresholds)

# -----------------------------
# 4) Regime classification
# -----------------------------
df_reg <- df2 %>%
  mutate(
    # A) Rate direction regime
    rate_direction_regime = case_when(
      is.na(d12_effr_pp) ~ NA_character_,
      d12_effr_pp >  DIRECTION_THRESHOLD_PP ~ "Rising",
      d12_effr_pp < -DIRECTION_THRESHOLD_PP ~ "Falling",
      TRUE ~ "Stable"
    ),
    
    # B) Rate level regime (percentiles)
    rate_level_regime = case_when(
      is.na(EFFR) | is.na(effr_p25) | is.na(effr_p75) ~ NA_character_,
      EFFR < effr_p25 ~ "Low",
      EFFR > effr_p75 ~ "High",
      TRUE ~ "Mid"
    ),
    
    # C) Inflation regime (percentiles)
    inflation_regime = case_when(
      is.na(inflation_yoy) | is.na(infl_p25) | is.na(infl_p75) ~ NA_character_,
      inflation_yoy < infl_p25 ~ "Low",
      inflation_yoy > infl_p75 ~ "High",
      TRUE ~ "Moderate"
    ),
    
    # D) Joint regime label (useful for grouped summaries later)
    joint_regime = if_else(
      is.na(rate_direction_regime) | is.na(inflation_regime),
      NA_character_,
      paste(inflation_regime, rate_direction_regime, sep = " + ")
    )
  )

# -----------------------------
# 5) QA summaries
# -----------------------------
regime_counts <- df_reg %>%
  summarise(
    n_rows = n(),
    n_complete_regimes = sum(!is.na(rate_direction_regime) & !is.na(rate_level_regime) & !is.na(inflation_regime)),
    n_rate_direction_missing = sum(is.na(rate_direction_regime)),
    n_rate_level_missing = sum(is.na(rate_level_regime)),
    n_inflation_missing = sum(is.na(inflation_regime))
  )

regime_counts_long <- df_reg %>%
  select(rate_direction_regime, rate_level_regime, inflation_regime, joint_regime) %>%
  pivot_longer(cols = everything(), names_to = "regime_type", values_to = "regime") %>%
  mutate(regime = if_else(is.na(regime), "(Missing)", regime)) %>%
  count(regime_type, regime, name = "n") %>%
  arrange(regime_type, desc(n))

out_counts_summary <- file.path(DIRS$tables, "regime_counts_summary.csv")
out_counts_long <- file.path(DIRS$tables, "regime_counts.csv")

write_csv(regime_counts, out_counts_summary)
write_csv(regime_counts_long, out_counts_long)

# -----------------------------
# 6) Save processed dataset
# -----------------------------
out_rds <- file.path(DIRS$processed, "macro_asset_monthly_with_regimes.rds")
out_csv <- file.path(DIRS$processed, "macro_asset_monthly_with_regimes.csv")

saveRDS(df_reg, out_rds)
write_csv(df_reg, out_csv)

message("Saved regime-enriched dataset:")
message(" - ", out_rds)
message(" - ", out_csv)

message("Saved regime QA tables:")
message(" - ", out_thresholds)
message(" - ", out_counts_summary)
message(" - ", out_counts_long)

message("02_regime_classification.R complete.")
