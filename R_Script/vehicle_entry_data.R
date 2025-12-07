library(tidyverse)
library(janitor)

# Load vehicle entries dataset
crz_raw <- read_csv("MTA_Congestion_Relief_Zone_Vehicle_Entries__Beginning_2025_20251205.csv") %>%
  clean_names() 
crz_daily <- crz_raw %>%
  mutate(
    date = as.Date(toll_date, format = "%m/%d/%Y"),
    crz_entries = as.numeric(crz_entries)
  ) %>%
  group_by(date) %>%
  summarise(
    total_crz_entries = sum(crz_entries, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(date)
# Save output
write_csv(crz_daily, "MTA_CRZ_entries_daily.csv")