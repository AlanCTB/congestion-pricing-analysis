library(readr)
library(dplyr)

# File paths

base_dir  <- "C:/Users/alanc/Documents/Final Project"

file_2024 <- file.path(base_dir, "MTA_Subway_Station_Ridership_Summary_2024_JanSep.csv")
file_2025 <- file.path(base_dir, "MTA_Subway_Station_Ridership_Summary_2025_JanSep.csv")

# ============================================================
# 2. Read the summary files
# ============================================================

s24 <- read_csv(file_2024, show_col_types = FALSE)
s25 <- read_csv(file_2025, show_col_types = FALSE)

# ============================================================
# 3. Join 2024 + 2025 and compute raw + % changes
# ============================================================

stations_change <- s24 %>%
  # keep id, totals, and station metadata from 2024
  select(station_complex_id, starts_with("total_"), everything()) %>%
  # join 2025 totals; 
  left_join(
    s25 %>%
      select(station_complex_id, starts_with("total_")),
    by = "station_complex_id",
    suffix = c("_2024", "_2025")
  ) %>%
  # raw changes
  mutate(
    diff_from_all    = total_from_all_2025    - total_from_all_2024,
    diff_to_all      = total_to_all_2025      - total_to_all_2024,
    diff_from_to_cbd = total_from_to_cbd_2025 - total_from_to_cbd_2024,
    diff_to_from_cbd = total_to_from_cbd_2025 - total_to_from_cbd_2024
  ) %>%
  # percentage changes
  mutate(
    pct_from_all    = if_else(total_from_all_2024    > 0, 100 * diff_from_all    / total_from_all_2024,    NA_real_),
    pct_to_all      = if_else(total_to_all_2024      > 0, 100 * diff_to_all      / total_to_all_2024,      NA_real_),
    pct_from_to_cbd = if_else(total_from_to_cbd_2024 > 0, 100 * diff_from_to_cbd / total_from_to_cbd_2024, NA_real_),
    pct_to_from_cbd = if_else(total_to_from_cbd_2024 > 0, 100 * diff_to_from_cbd / total_to_from_cbd_2024, NA_real_)
  ) %>%
  # round percentage numerics to 2 decimals
  mutate(
    across(
      c(pct_from_all, pct_to_all, pct_from_to_cbd, pct_to_from_cbd),
      ~ round(., 2)
    )
  ) %>%

# ============================================================
# 4. Save output
# ============================================================

out_change <- file.path(base_dir, "MTA_Subway_Station_Ridership_Change_2024_2025_JanSep.csv")
write_csv(stations_change, out_change)

cat("Saved change table to:\n", out_change, "\n")
