library(readr)
library(dplyr)
library(tidyr)

# file path
path <- "C:/Users/alanc/Documents/Final Project/MTA_Subway_Station_Ridership_Change_2024_2025_JanSep.csv"

# Read the dataset
change_df <- read_csv(path, show_col_types = FALSE)

# Georeference -> lon / lat and add as new columns
change_df <- change_df %>%
  mutate(
    Georeference_clean = gsub("POINT \\(|\\)", "", Georeference)
  ) %>%
  separate(
    Georeference_clean,
    into = c("georef_lon", "georef_lat"),
    sep = " ",
    convert = TRUE
  )

#  Save as a new file
out_with_coords <- "C:/Users/alanc/Documents/Final Project/MTA_Subway_Station_Ridership_Change_2024_2025_JanSep_with_coords.csv"
write_csv(change_df, out_with_coords)

cat("Saved file with lon/lat to:\n", out_with_coords, "\n")

