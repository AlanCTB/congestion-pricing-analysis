library(sf)
library(dplyr)
library(readr)

# Load NTA shapefile
nta_path <- "C:/Users/alanc/Documents/Final Project/nynta2020_25d/nynta2020.shp"
nta <- st_read(nta_path)

# Transform NTA to EPSG:4326 to match station coords
nta <- st_transform(nta, 4326)

# Load station ridership change dataset
stations_path <- "C:/Users/alanc/Documents/Final Project/MTA_Subway_Station_Ridership_Change_2024_2025_JanSep_with_coords.csv"
stations <- read_csv(stations_path)

# Convert station table into sf POINTS
stations_sf <- st_as_sf(
  stations,
  coords = c("georef_lon", "georef_lat"),
  crs = 4326,
  remove = FALSE
)

# Spatial join: assign each station to an NTA
stations_with_nta <- st_join(stations_sf, nta, left = TRUE)

# Aggregate to NTA level
nta_summary <- stations_with_nta %>%
  st_drop_geometry() %>%
  group_by(NTA2020, NTAName) %>%  
  summarise(
    total_from_all_2024    = sum(total_from_all_2024,    na.rm = TRUE),
    total_from_all_2025    = sum(total_from_all_2025,    na.rm = TRUE),
    diff_from_all          = sum(diff_from_all,          na.rm = TRUE),
    
    total_from_to_cbd_2024 = sum(total_from_to_cbd_2024, na.rm = TRUE),
    total_from_to_cbd_2025 = sum(total_from_to_cbd_2025, na.rm = TRUE),
    diff_from_to_cbd       = sum(diff_from_to_cbd,       na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    pct_from_all = if_else(
      total_from_all_2024 > 0,
      100 * (total_from_all_2025 - total_from_all_2024) / total_from_all_2024,
      NA_real_
    ),
    pct_from_to_cbd = if_else(
      total_from_to_cbd_2024 > 0,
      100 * (total_from_to_cbd_2025 - total_from_to_cbd_2024) / total_from_to_cbd_2024,
      NA_real_
    )
  ) %>%

# Join summary back onto NTA shape for mapping
nta_sf_summary <- nta %>%
  left_join(nta_summary, by = "NTA2020")

# Save to CSV & shapefile
write_csv(
  nta_summary,
  "C:/Users/alanc/Documents/Final Project/NTA_Subway_Ridership_Change_2024_2025.csv"
)

st_write(
  nta_sf_summary,
  "C:/Users/alanc/Documents/Final Project/NTA_Subway_Ridership_Change_2024_2025.shp",
  overwrite = TRUE,
  append = FALSE
)
