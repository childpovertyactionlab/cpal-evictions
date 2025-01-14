library(tidyverse)
library(tidycensus)
library(sf)

acs_tbl <- load_variables("acs5/subject", year = 2023)

years <- 2017:2023

renter_tbl <- map_dfr(years, function(yr) {
  get_acs(
    geography = "congressional district",
    year = yr,
    variables = c(rohh = "B25012_010",
                  pop_u18 = "S1701_C01_002",
                  bp_u18 = "S1701_C02_002"),
    geometry = TRUE,
    output = "wide"
  ) %>%
    mutate(year = yr, cpr = bp_u18E / pop_u18E)
})

evictions_tbl <- rio::import("data/NTEP_eviction_cases.csv")
  
evictions_tbl %>%
  group_by(lubridate::year(date), county_id) %>%
  summarize(count = n()) %>%
  rename(year = 1) %>%
  pivot_wider(names_from = county_id,
              values_from = count)

# make into sf object and filter to only include dallas county evictions
evictions_sf <- evictions_tbl %>%
  mutate(year = lubridate::year(date)) %>%
  filter(county_id %in% c("48113", "48439")) %>%
  filter(!is.na(lon)) %>%
  st_as_sf(coords = c(x = "lon", y = "lat"), crs = 4269)

# filter evictions to only include those within cd 30 for jasmine crocketts district
cd30 <- renter_tbl %>%
  filter(GEOID == "4830")

# Iterate over unique years and filter evictions_sf based on cd30 boundaries
cd30_evictions <- map_dfr(unique(evictions_sf$year), function(yr) {
  
  # Use 2023 polygon for 2024 data
  cd30_year <- if (yr == 2024) {
    cd30 %>% filter(year == 2023)
  } else {
    cd30 %>% filter(year == yr)
  }
  
  # Filter evictions_sf records that intersect with cd30_year's polygon
  evictions_filtered <- evictions_sf %>%
    filter(year == yr) %>%  # Filter evictions for the current year
    st_filter(cd30_year)    # Spatial filter based on cd30 boundary
  
  # Summarize filtered data for the current year
  evictions_summary <- evictions_filtered %>%
    st_drop_geometry() %>%
    group_by(year = yr) %>%
    summarize(
      count = n(),
      filing_amount_mean = mean(amount[amount > 0], na.rm = TRUE),
      filing_amount_med = median(amount[amount > 0], na.rm = TRUE),
      amount_na_count = sum(is.na(amount)),
      amount_gt0_count = sum(amount > 0, na.rm = TRUE),
      amount_eq0_count = sum(amount == 0, na.rm = TRUE)
    )
  
  return(evictions_summary)
})

# Join summarized data back to cd30 without geometry
cd30_evictions <- left_join(cd30_evictions, st_drop_geometry(cd30), by = "year")

dallas_evictions <- evictions_tbl %>%
  mutate(year = lubridate::year(date)) %>%
  filter(county_id %in% c("48113")) %>%
  group_by(year) %>%
  summarize(
    count = n(),
    filing_amount_mean = mean(amount, na.rm = TRUE),
    filing_amount_med = median(amount, na.rm = TRUE),
    amount_na_count = sum(is.na(amount)),
    amount_gt0_count = sum(amount > 0, na.rm = TRUE),
    amount_eq0_count = sum(amount == 0, na.rm = TRUE),
    total_amount = sum(amount, na.rm = TRUE)
  )

#googlesheets4::write_sheet(cd30_evictions)
