# ============================================================
# 04_visualizations.R
# Purpose: Generate visual outputs for the macro regime project
# Inputs:  data/processed/asset_returns_with_regimes.{csv|rds}
# Outputs: output/figures/*.png
# ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
  library(ggplot2)
  library(scales)
})

# -----------------------------
# 0) Paths
# -----------------------------
PROJECT_DIR <- getwd()

DIRS <- list(
  processed = file.path(PROJECT_DIR, "data", "processed"),
  figures = file.path(PROJECT_DIR, "output", "figures")
)

create_dir_safe <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
invisible(lapply(DIRS, create_dir_safe))

in_path_rds <- file.path(DIRS$processed, "asset_returns_with_regimes.rds")
in_path_csv <- file.path(DIRS$processed, "asset_returns_with_regimes.csv")

df <- if (file.exists(in_path_rds)) {
  readRDS(in_path_rds)
} else if (file.exists(in_path_csv)) {
  read_csv(in_path_csv, show_col_types = FALSE)
} else {
  stop("Cannot find asset_returns_with_regimes.{rds|csv}. Run Script 03 first.")
}

df <- df %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

# Standardize regime ordering for consistent legends
df <- df %>%
  mutate(
    rate_direction_regime = factor(rate_direction_regime, levels = c("Falling", "Stable", "Rising"))
  )

# A simple, clean theme
theme_clean <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# Helper: save plot
save_plot <- function(p, filename, width = 10, height = 6, dpi = 300) {
  ggsave(
    filename = file.path(DIRS$figures, filename),
    plot = p,
    width = width,
    height = height,
    dpi = dpi
  )
}

# -----------------------------
# 1) Plot: EFFR time series (context)
# -----------------------------
p1 <- ggplot(df, aes(x = date, y = EFFR)) +
  geom_line(linewidth = 0.6, na.rm = TRUE) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Effective Federal Funds Rate (Monthly)",
    x = "Date",
    y = "Rate (%)",
    caption = "Source: FRED (EFFR), monthly aggregation"
  ) +
  theme_clean

save_plot(p1, "fig01_effr_time_series.png")

# -----------------------------
# 2) Plot: S&P 500 cumulative index with regime shading (most impressive)
# -----------------------------
# Build a monthly equity cumulative index from log returns:
# cum_index = exp(cumsum(log_returns)) * 100 (base=100)
df_cum <- df %>%
  filter(!is.na(ret_sp500_log)) %>%
  mutate(
    cum_equity_index = exp(cumsum(ret_sp500_log)) * 100
  )

# Create regime "runs" for shading rectangles (continuous spans of same regime)
shade_df <- df_cum %>%
  filter(!is.na(rate_direction_regime)) %>%
  mutate(
    reg = as.character(rate_direction_regime),
    reg_change = reg != dplyr::lag(reg, default = first(reg)),
    run_id = cumsum(reg_change)
  ) %>%
  group_by(run_id, reg) %>%
  summarise(
    start = min(date),
    end = max(date),
    .groups = "drop"
  )

p2 <- ggplot() +
  # Shaded regime background
  geom_rect(
    data = shade_df,
    aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, fill = reg),
    alpha = 0.15,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = df_cum,
    aes(x = date, y = cum_equity_index),
    linewidth = 0.7,
    na.rm = TRUE
  ) +
  scale_y_continuous(labels = label_number()) +
  labs(
    title = "S&P 500 Cumulative Performance with Interest-Rate Regime Shading",
    x = "Date",
    y = "Cumulative Index (Base = 100)",
    fill = "Rate Direction Regime",
    caption = "Equity series uses SP500 (price index) from FRED; regimes from 12-month changes in EFFR."
  ) +
  theme_clean

save_plot(p2, "fig02_sp500_cumulative_with_regime_shading.png", width = 11, height = 6)

# -----------------------------
# 3) Plot: Return distribution by rate direction regime (boxplot)
# -----------------------------
# Use percent for interpretability: log return ~ approx % for small values
df_box <- df %>%
  filter(!is.na(ret_sp500_log), !is.na(rate_direction_regime)) %>%
  mutate(ret_sp500_pct = ret_sp500_log * 100)

p3 <- ggplot(df_box, aes(x = rate_direction_regime, y = ret_sp500_pct)) +
  geom_boxplot(outlier.alpha = 0.25, na.rm = TRUE) +
  geom_hline(yintercept = 0, linewidth = 0.4, linetype = "dashed") +
  labs(
    title = "Monthly S&P 500 Returns by Interest-Rate Direction Regime",
    x = "Rate Direction Regime",
    y = "Monthly Return (log, %)",
    caption = "Returns computed from SP500 (price index). Boxplots show distribution by regime."
  ) +
  theme_clean

save_plot(p3, "fig03_sp500_returns_boxplot_by_regime.png")

# -----------------------------
# 4) Plot: Annualized mean returns by regime (bar chart)
# -----------------------------
# Compute annualized mean and annualized volatility by regime
summary_reg <- df %>%
  filter(!is.na(ret_sp500_log), !is.na(rate_direction_regime)) %>%
  group_by(rate_direction_regime) %>%
  summarise(
    n = n(),
    mean_monthly = mean(ret_sp500_log, na.rm = TRUE),
    sd_monthly = sd(ret_sp500_log, na.rm = TRUE),
    annualized_mean = mean_monthly * 12,
    annualized_sd = sd_monthly * sqrt(12),
    se_monthly = sd_monthly / sqrt(n),
    # very simple 95% CI on monthly mean (for visualization; not HAC-adjusted)
    ci_low_ann = (mean_monthly - 1.96 * se_monthly) * 12,
    ci_high_ann = (mean_monthly + 1.96 * se_monthly) * 12,
    .groups = "drop"
  )

p4 <- ggplot(summary_reg, aes(x = rate_direction_regime, y = annualized_mean)) +
  geom_col(na.rm = TRUE) +
  geom_errorbar(aes(ymin = ci_low_ann, ymax = ci_high_ann), width = 0.2, na.rm = TRUE) +
  scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
  labs(
    title = "Annualized Mean Equity Returns by Interest-Rate Direction Regime",
    x = "Rate Direction Regime",
    y = "Annualized Mean Return",
    caption = "Error bars show simple 95% CI on the mean (not adjusted for time-series dependence)."
  ) +
  theme_clean

save_plot(p4, "fig04_sp500_annualized_mean_by_regime.png")

message("04_visualizations.R complete. Figures saved to output/figures/.")
