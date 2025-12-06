Author: Alan Chen & Josiah  
Date: Dec 2025  

This document describes the data sources and general steps I followed in R, QGIS & Datawrapper to produce the maps and charts used in the final congestion pricing project.

---

## 1) Study scope

**Geography:**

- New York City, with a primary focus on the Manhattan Central Business District (CBD) and adjacent neighborhoods in Brooklyn, Queens, and the Bronx.

**Timeframes:**

- Vehicle entries: 
- Crashes: Jan 2024 – Oct 2025 (used for year-over-year before/after comparisons).
- Subway ridership: Jan–Sep 2024 vs. Jan–Sep 2025.
- Polling numbers: 

**Units of analysis:**

- Vehicle entries: 
- Crashes: primarily ZIP/MODZCTA and custom clusters (end-of-line areas in Queens and the Bronx), with a separate CBD vs. non-CBD cut.
- Subway ridership: station complexes (MTA station_complex_id) and NYC NTAs (NTA2020) for neighborhood-level aggregation.
- Polling numbers:

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

- Polling time series on congestion pricing approval vs. disapproval (source noted in figure caption).

---

## 3) Crash analysis workflow (QGIS + basic aggregation)

This mirrors what I wrote up for Assignment 2, but extended to support the before/after framing in this project.

### 3.1 QGIS setup

- Project CRS: EPSG:4326.

**Layers added:**

- Crash CSV from NYC Open Data (2024–2025).
- MODZCTA polygons.
- Borough boundaries.
- CBD geofence polygon.
- Subway lines (for visual context).

### 3.2 Time filters and year-specific crash layers

Created filtered layers in QGIS:

- `crashes_2024`: crashes from Jan–Oct 2024.
- `crashes_2025`: crashes from Jan–Oct 2025.

### 3.3 Points-in-Polygon aggregation (MODZCTA)

For each year, I used **Count Points in Polygon**:  
`Vector → Analysis Tools → Count points in polygon`

- Polygons: MODZCTA.
- Points: `crashes_2024` → output field `n_2024`.
- Points: `crashes_2025` → output field `n_2025` on the same MODZCTA layer.

Then, in the Field Calculator, I computed:

**Percent change per ZIP/MODZCTA**

```text
pct_change = 100 * (n_2025 - n_2024) / n_2024
