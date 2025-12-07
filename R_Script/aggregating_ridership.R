library(readr)
library(dplyr)
library(sf)
library(tidyr)

# File paths
# You Need to download MTA Subway_origin-Destination_Ridership for 2024 & 2025
# off of https://data.ny.gov/ both of those data sets are around 15GBs each

od_2024_path <- "MTA_Subway_Origin-Destination_Ridership_Estimate__2024.csv"
od_2025_path <- "MTA_Subway_Origin-Destination_Ridership_Estimate__Beginning_2025.csv"
cbd_path     <- "MTA_Central_Business_District_Geofence__Beginning_June_2024_20251205.csv"
stations_path <- "MTA_Subway_Stations.csv"

out_dir <- "C:/Users/alanc/Documents/Final Project"

# ============================================================
# 1. Read OD ridership files
# ============================================================

od_2024 <- read_csv(od_2024_path)
od_2025 <- read_csv(od_2025_path)

# filter to Jan-Sept
od_2024_jansep <- od_2024 %>%
  filter(Month %in% 1:9)

od_2025_jansep <- od_2025 %>%
  filter(Month %in% 1:9)


# Build key sets
keys_24 <- od_2024_jansep %>%
  distinct(
    Month, `Day of Week`, `Hour of Day`,
    `Origin Station Complex ID`,
    `Destination Station Complex ID`
  )

keys_25 <- od_2025_jansep %>%
  distinct(
    Month, `Day of Week`, `Hour of Day`,
    `Origin Station Complex ID`,
    `Destination Station Complex ID`
  )

# Intersection of keys = OD × time cells present in BOTH years
common_keys <- inner_join(
  keys_24,
  keys_25,
  by = c(
    "Month", "Day of Week", "Hour of Day",
    "Origin Station Complex ID",
    "Destination Station Complex ID"
  )
)

nrow(common_keys)  # checking balanced size

# Filter each dataset to those common cells
od_2024_balanced <- od_2024_jansep %>%
  semi_join(
    common_keys,
    by = c(
      "Month", "Day of Week", "Hour of Day",
      "Origin Station Complex ID",
      "Destination Station Complex ID"
    )
  )

od_2025_balanced <- od_2025_jansep %>%
  semi_join(
    common_keys,
    by = c(
      "Month", "Day of Week", "Hour of Day",
      "Origin Station Complex ID",
      "Destination Station Complex ID"
    )
  )

#  Check row counts:
nrow(od_2024_balanced)
nrow(od_2025_balanced)

# ============================================================
# 2. Read CBD geofence 
# ============================================================
cbd_raw <- read_csv(cbd_path, show_col_types = FALSE)
cbd <- st_as_sf(cbd_raw, wkt = "polygon", crs = 4326)

cbd_poly <- st_union(cbd)
# ============================================================
# 3. Read stations + flag CBD
# ============================================================

stations_raw <- read_csv(stations_path, show_col_types = FALSE)

station_id_col <- "Complex ID"
lat_col        <- "GTFS Latitude"
lon_col        <- "GTFS Longitude"

# Make stations sf points
stations_sf <- stations_raw %>%
  st_as_sf(coords = c(lon_col, lat_col), crs = 4326)

# Flag if station is inside CBD polygon
stations_cbd_sf <- stations_sf %>%
  mutate(is_cbd = as.logical(st_within(., cbd_poly, sparse = FALSE)[, 1]))

# Drop geometry but keep all attributes + CBD flag
stations_lookup <- stations_cbd_sf %>%
  st_drop_geometry() %>%
  rename(station_complex_id = !!sym(station_id_col)) %>%
  distinct(station_complex_id, .keep_all = TRUE)
# ============================================================
# 4. Helper: compute 4 metrics for a given year's OD 
#           using estimated TOTAL ridership, not averages
# ============================================================

compute_station_metrics <- function(od_df, stations_lookup) {
  
  # Standardize column names used inside the function 
  od_df <- od_df %>%
    rename(
      year                       = Year,
      month                      = Month,
      day_of_week                = `Day of Week`,
      hour_of_day                = `Hour of Day`,
      origin_station_complex_id  = `Origin Station Complex ID`,
      destination_station_complex_id = `Destination Station Complex ID`,
      estimated_average_ridership    = `Estimated Average Ridership`
    )
  
  # Build day-of-week counts for the months in this OD dataset
  years_months <- od_df %>%
    distinct(year, month)
  
  dow_counts <- years_months %>%
    rowwise() %>%
    do({
      yr <- .$year
      mo <- .$month
      start <- as.Date(sprintf("%d-%02d-01", yr, mo))
      end   <- ceiling_date(start, "month") - 1
      tibble(date = seq(start, end, by = "day")) %>%
        mutate(
          year        = yr,
          month       = mo,
          day_of_week = weekdays(date)   # "Monday", "Tuesday", ...
        )
    }) %>%
    ungroup() %>%
    count(year, month, day_of_week, name = "n_days")
  
  # Convert average ridership → estimated TOTAL ridership
  od_df_totals <- od_df %>%
    left_join(dow_counts, by = c("year", "month", "day_of_week")) %>%
    mutate(
      est_total_ridership = estimated_average_ridership * n_days
    )
  
  # Attach CBD flags to origin & destination 
  od_with_cbd <- od_df_totals %>%
    left_join(
      stations_lookup %>%
        select(station_complex_id, origin_is_cbd = is_cbd),
      by = c("origin_station_complex_id" = "station_complex_id")
    ) %>%
    left_join(
      stations_lookup %>%
        select(station_complex_id, destination_is_cbd = is_cbd),
      by = c("destination_station_complex_id" = "station_complex_id")
    )
  
  # Aggregate TOTALS by station
  
  # 1) From station → ALL destinations (origin-based) — TOTAL
  orig_all <- od_with_cbd %>%
    group_by(origin_station_complex_id) %>%
    summarise(
      total_from_all = sum(est_total_ridership, na.rm = TRUE),
      .groups = "drop"
    )
  
  # To station ← ALL origins (destination-based) — TOTAL
  dest_all <- od_with_cbd %>%
    group_by(destination_station_complex_id) %>%
    summarise(
      total_to_all = sum(est_total_ridership, na.rm = TRUE),
      .groups = "drop"
    )
  
  # From station → CBD destinations — TOTAL
  orig_to_cbd <- od_with_cbd %>%
    filter(destination_is_cbd) %>%
    group_by(origin_station_complex_id) %>%
    summarise(
      total_from_to_cbd = sum(est_total_ridership, na.rm = TRUE),
      .groups = "drop"
    )
  
  # To station ← CBD origins — TOTAL
  dest_from_cbd <- od_with_cbd %>%
    filter(origin_is_cbd) %>%
    group_by(destination_station_complex_id) %>%
    summarise(
      total_to_from_cbd = sum(est_total_ridership, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Merge back to stations (keep all station info) 
  station_summary <- stations_lookup %>%
    left_join(orig_all,
              by = c("station_complex_id" = "origin_station_complex_id")) %>%
    left_join(dest_all,
              by = c("station_complex_id" = "destination_station_complex_id")) %>%
    left_join(orig_to_cbd,
              by = c("station_complex_id" = "origin_station_complex_id")) %>%
    left_join(dest_from_cbd,
              by = c("station_complex_id" = "destination_station_complex_id")) %>%
    mutate(
      total_from_all    = replace_na(total_from_all, 0),
      total_to_all      = replace_na(total_to_all, 0),
      total_from_to_cbd = replace_na(total_from_to_cbd, 0),
      total_to_from_cbd = replace_na(total_to_from_cbd, 0)
    )
  
  station_summary
}

# ============================================================
# 5. Compute metrics for 2024 (Jan–Sept) and 2025 (Jan–Sept)
# ============================================================

station_summary_2024 <- compute_station_metrics(od_2024_balanced, stations_lookup)
station_summary_2025 <- compute_station_metrics(od_2025_balanced, stations_lookup)

# ============================================================
# 6. Save outputs
# ============================================================

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

out_2024 <- file.path(out_dir, "MTA_Subway_Station_Ridership_Summary_2024_JanSep.csv")
out_2025 <- file.path(out_dir, "MTA_Subway_Station_Ridership_Summary_2025_JanSep.csv")

write_csv(station_summary_2024, out_2024)
write_csv(station_summary_2025, out_2025)

cat("Saved:\n", out_2024, "\n", out_2025, "\n")
