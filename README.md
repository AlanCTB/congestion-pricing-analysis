Author: Alan Chen & Josiah  
Date: Dec 6 2025  

This document describes the data sources and general steps we followed in R, QGIS & Datawrapper to produce the maps and charts used in the final congestion pricing project.

---

## 1) Study scope

**Geography:**

- New York City, with a primary focus on the Manhattan Central Business District (CBD) and adjacent neighborhoods in Brooklyn, Queens, and the Bronx.

**Timeframes:**

- Vehicle entries: 2024 - June 2025 (comparisions used in the article)
- Crashes: Jan 2024 – Oct 2025 (used for year-over-year before/after comparisons).
- Subway ridership: Jan–Sep 2024 vs. Jan–Sep 2025.
- Polling numbers: Apr 2024 - March 2025 (Polling dates)

**Units of analysis:**

- Vehicle entries: The article contained raw vehicle entries into the CBD.
- Crashes: primarily ZIP/MODZCTA and custom clusters (end-of-line areas in Queens and the Bronx), with a separate CBD vs. non-CBD.
- Subway ridership: station complexes (MTA station_complex_id) and NYC NTAs (NTA2020) for neighborhood-level aggregation.
- Polling numbers: Public Opinion polling for New Yorkers support for Congestion Pricing. 

---

## 2) Data sources (links)

### Crashes

**Motor Vehicle Collisions – Crashes (NYPD) — NYC Open Data**  
Records of reported crashes with coordinates, injuries, and severity.  
<https://data.cityofnewyork.us/Public-Safety/Motor-Vehicle-Collisions-Crashes/h9gi-nx95>

**MODZCTA (Modified Zip Code Tabulation Areas) — NYC Open Data**  
Polygon boundaries used to aggregate crash counts and changes.  
<https://data.cityofnewyork.us/Health/Modified-Zip-Code-Tabulation-Areas-MODZCTA-/pri4-ifjk/about_data>

**Borough Boundaries – NYC Planning**  
Used to define borough-level crash summaries and cluster areas.  
<https://www.nyc.gov/content/planning/pages/resources/datasets/borough-boundaries>

### Transit / Spatial context

**Subway Lines — GIS Lab, Newman Library (Baruch CUNY)**  
Used for context in the crash and ridership maps.  
<https://geo.nyu.edu/catalog/nyu-2451-34758>

**MTA Central Business District Geofence: Beginning June 2024 — Data.gov**  
Official polygon for the congestion pricing tolling zone (south of ~60th St).  
<https://catalog.data.gov/dataset/mta-central-business-district-geofence-beginning-june-2024>

**NYC NTA 2020 Shapefile (NYC Planning)**  
Neighborhood Tabulation Areas used to aggregate station-level ridership changes to neighborhood level.  
<https://www.nyc.gov/content/planning/pages/resources/datasets/neighborhood-tabulation>

### Subway ridership

**MTA Subway Origin–Destination Ridership Estimate: 2024**  
Estimated average ridership for every OD pair by year, month, day of week, and hour of day.  
<https://data.ny.gov/Transportation/MTA-Subway-Origin-Destination-Ridership-Estimate-2/jsu2-fbtj/about_data>

**MTA Subway Origin–Destination Ridership Estimate: Beginning 2025**  
Same structure as 2024, including trips across Jan–Sep 2025.  
<https://data.ny.gov/Transportation/MTA-Subway-Origin-Destination-Ridership-Estimate-B/y2qv-fytt/about_data>

**MTA Subway Stations**  
Station complex IDs, stop names, boroughs, routes, CBD flag, and a Georeference POINT field used to create lon/lat.  
<https://catalog.data.gov/dataset/mta-subway-stations>

### Opinion / polling data

- The polling numbers are pulled from the pollsters below. 
- Polling time series on congestion pricing approval vs. disapproval.
<https://sri.siena.edu/wp-content/uploads/2025/07/SNY0424-Crosstabs_UpdatedMethodology.pdf>
<https://sri.siena.edu/wp-content/uploads/2025/07/SNY0325-ALL-Crosstabs_UpdatedMethodology.pdf>
<https://sri.siena.edu/wp-content/uploads/2025/07/SNY1224ALL-Crosstabs_UpdatedMethodology.pdf>

### Vehicle Entries

- We couldn't find raw numbers for Vehicle Entries into the CBD before the program, so we 
<https://www.governor.ny.gov/news/six-months-governor-hochul-highlights-success-congestion-pricing-traffic-down-business-and>
---

### 3) Crash analysis workflow (QGIS + basic aggregation)


#### 3.1 QGIS setup

- **Project CRS**: `EPSG:4326`

**Layers added:**

- Crash CSV from NYC Open Data (2024–2025)  
- MODZCTA polygons  
- Borough boundaries  
- CBD geofence polygon  
- Subway lines (for visual context)  

---

#### 3.2 Time filters and year-specific crash layers

Created filtered layers in QGIS:

- `crashes_2024`: crashes from **Jan–Oct 2024**  
- `crashes_2025`: crashes from **Jan–Oct 2025**  

---

#### 3.3 Points-in-Polygon aggregation (MODZCTA)

For each year, I used **Count points in polygon**:

> **Vector → Analysis Tools → Count points in polygon**

- **Polygons**: MODZCTA  
- **Points**: `crashes_2024` → output field `n_2024`  
- **Points**: `crashes_2025` → output field `n_2025` on the same MODZCTA layer  

Then, in the Field Calculator, I computed **percent change per ZIP/MODZCTA**:

```text
pct_change = 100 * (n_2025 - n_2024) / n_2024
``` 
#### 3.4 CBD vs non-CBD and cluster zones

To make the story more interpretable, I defined six broad clusters:

- **Manhattan — CBD** (`Manhattan ∩ CBD` polygon)  
- **Manhattan — Non-CBD** (`Manhattan − CBD` polygon)  
- **Brooklyn**  
- **Queens**  
- **Bronx**  
- **Staten Island**

**Using QGIS:**

- **Clip & difference**
  - `Manhattan_CBD = Manhattan ∩ CBD`
  - `Manhattan_nonCBD = Manhattan − CBD`
- **Merge** vector layers to assemble cluster polygons where needed.

I then summarized crash counts and changes by:

- CBD vs citywide  
- Each borough  
- A few areas at the ends of subway lines in Queens and the Bronx  
  (identified visually on the crash + transit map)

---

#### 3.5 Symbology & export

**Symbology:**

- Graduated symbology on `pct_change` with a diverging color ramp (red ↔ blue).
- Consistent bins across comparable maps so colors mean the same change.

**Basemap:**

- Neutral grayscale XYZ tile (e.g., Carto light).

**Export:**

- `Project → Import/Export → Export Map to Image/PDF`
- DPI: **300**

These crash maps provide the safety story that the ridership analysis later mirrors spatially.

### 4) Subway ridership analysis (R)

This section describes how I processed the MTA OD ridership data to estimate changes in CBD-bound subway trips at both **station** and **neighborhood** levels.  

All of this is done in **R**, mainly with:

- `dplyr`
- `readr`
- `sf`
- `tidyr`
- `lubridate`

---

#### 4.1 Load and filter the OD datasets

**Source files:**

- `MTA_Subway_Origin-Destination_Ridership_Estimate__2024.csv`  
- `MTA_Subway_Origin-Destination_Ridership_Estimate__Beginning_2025.csv`

In R, I:

- Read each file with `readr::read_csv()`.
- Renamed columns to `snake_case`  
  (e.g., `Year → year`, `Origin Station Complex ID → origin_station_complex_id`).
- Filtered to **Jan–Sep** with `month %in% 1:9`.
- Dropped rows with missing `estimated_average_ridership`.

This produced:

- `od_2024_jansep`
- `od_2025_jansep`

---

#### 4.2 Build a balanced OD–time panel

The raw **2025** file contains more OD–time bins than 2024, so **directly summing** would artificially inflate changes.  
To avoid this, I created a **balanced panel**.

I:

- Defined a key:  
  `(month, day_of_week, hour_of_day, origin_station_complex_id, destination_station_complex_id)`.
- For each year, built a data frame of unique keys.
- Used `dplyr::inner_join()` to keep only the keys present in **both** years.
- Filtered `od_2024_jansep` and `od_2025_jansep` to these common keys, yielding:
  - `od_2024_balanced`
  - `od_2025_balanced`

This way ensures that I’m comparing **like-for-like OD–hour cells** between years.

---

#### 4.3 Convert average ridership → estimated totals

The OD dataset provides **average ridership per hour**, by **day of week** and **month**.  
To approximate **total ridership**, I:

For each `(year, month, day_of_week)`, computed the number of calendar days using `lubridate`:

```r
dow_counts <- od_df %>%
  distinct(year, month) %>%
  rowwise() %>%
  do({
    yr <- .$year
    mo <- .$month
    start <- as.Date(sprintf("%d-%02d-01", yr, mo))
    end   <- ceiling_date(start, "month") - 1
    tibble(date = seq(start, end, by = "day")) %>%
      mutate(
        year        = year(date),
        month       = month(date),
        day_of_week = weekdays(date)
      )
  }) %>%
  ungroup() %>%
  count(year, month, day_of_week, name = "n_days")
```
#### 4.4 Flag CBD stations using the geofence

To figure out which trips are **“CBD-bound,”** I needed to know which station complexes lie inside the congestion zone.

Steps:

- Loaded `MTA_Subway_Stations.csv` and parsed the `Georeference` `POINT` column into  
  `georef_lon` and `georef_lat` using **dplyr** + `tidyr::separate()`.
- Converted stations to `sf` points (`crs = 4326`).
- Loaded the **CBD geofence** CSV and converted its polygon field to an `sf` polygon.
- Used `st_within()` to mark each station as inside or outside the CBD:  
  `is_cbd = TRUE/FALSE`.
- Built a `stations_lookup` table keyed by `station_complex_id` with attributes like:
  - stop name  
  - borough  
  - routes  
  - `is_cbd`  

---

#### 4.5 Station-level metrics (four core measures)

For each of the **balanced OD datasets** (2024 and 2025), I used a helper function `compute_station_metrics()` that:

- Joins the OD data to the station lookup to tag origins and destinations with `is_cbd`.
- Aggregates estimated total ridership (`est_total_ridership`) into **four station-level totals**:

  - `total_from_all` – from this station → **all destinations**  
  - `total_to_all` – to this station ← **all origins**  
  - `total_from_to_cbd` – from this station → **CBD stations**  
  - `total_to_from_cbd` – to this station ← **CBD stations**

- Merges these totals back with full station metadata  
  (name, borough, routes, ADA, etc.), replacing missing totals with `0`.

This produced:

- `MTA_Subway_Station_Ridership_Summary_2024_JanSep.csv`  
- `MTA_Subway_Station_Ridership_Summary_2025_JanSep.csv`

---

#### 4.6 Year-over-year changes at the station level

I then compared **2024 vs. 2025** station totals in R:

- Joined the two station summaries by `station_complex_id`.
- Computed **raw differences** and **percentage changes**, with safe handling for zeros.
- For visualization (especially in **Datawrapper tooltips**), I also created  
  formatted string versions of key fields (e.g., **2 decimal places**, commas for thousands).

Final file used in the station-level map:

- `MTA_Subway_Station_Ridership_Change_2024_2025_JanSep_with_coords.csv`

---

#### 4.7 Aggregating station metrics to neighborhoods (NTAs)

To tell a **neighborhood** story, I:

- Loaded **NYC NTA 2020** (`nynta2020.shp`) as an `sf` layer and transformed it to `EPSG:4326`.
- Converted the station change dataset with `georef_lon` / `georef_lat` to `sf` points.
- Used `st_join()` to assign each station to:
  - `NTA2020`
  - `NTAName`
- Grouped by `NTA2020` and summed station totals:

  - `total_from_all_2024`, `total_from_all_2025`, `diff_from_all`  
  - `total_from_to_cbd_2024`, `total_from_to_cbd_2025`, `diff_from_to_cbd`

- Derived **NTA-level percentage changes**:

  - `pct_from_all`  
  - `pct_from_to_cbd`  

  both rounded to **2 decimals**.

- Saved these ridership summaries as:

  - `NTA_Subway_Ridership_Change_2024_2025.csv`

These are the inputs for the **NTA-level choropleth** showing where CBD-bound ridership grew the most (e.g., *Greenpoint, Williamsburg, South Williamsburg*) and where it stayed flat or declined (e.g., *Rockaways, outer Bronx*).

### 5) Maps, charts, and integration with the narrative

**Crash maps** (QGIS) show percent changes in crashes and injuries across ZIPs and clusters, highlighting that:

- The CBD and nearby neighborhoods saw ~5% crash reductions vs. \<2% citywide.  
- Certain end-of-line areas in Queens/Bronx saw ~12% increases.

**Ridership maps** (Datawrapper) visualize:

- Station-level changes in CBD-bound trips (Jan–Sep 2024 vs. Jan–Sep 2025).  
- NTA-level percentage changes, revealing strong growth in inner-ring, transit-rich neighborhoods and weaker or negative changes at the edges of the network.

An **opinion chart** (Datawrapper) ties the technical findings back to politics, showing that the program’s approval has improved as the benefits became visible.

Throughout our blog, each figure is tied to the workflow: crashes and ridership are treated as two sides of the same spatial story—where transit is strong, congestion pricing shows up as both fewer crashes and more subway trips into the CBD. Where transit is weak, cars fill the gap and safety gains are harder to find. The opinion chart is presented to enforce the overall messaging.

