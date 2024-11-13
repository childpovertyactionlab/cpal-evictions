#### Load necessary libraries #####
library(tidyverse)
library(rio)
library(sf)

libDB <- "C:/Users/Michael/CPAL Dropbox/"
# libDB <- "C:/Users/taylo/CPAL Dropbox/"
#libDB <- "/Users/anushachowdhury/CPAL Dropbox/" 
#libDB <- "C:/Users/erose/CPAL Dropbox/"

#### Generate dataframes with geometries #####
counties <- c("Dallas County",
              "Collin County",
              "Denton County",
              "Tarrant County")

ntx_counties <- tigris::counties(state = "TX", year = 2021) %>%
  filter(NAMELSAD %in% counties) %>%
  select(NAME, GEOID,  geometry) %>%
  rename(county_id = GEOID)

ntx_places <- tigris::places(state = "TX", year = 2021) %>%
  .[ntx_counties, ] %>%
  select(NAME, GEOID, geometry) %>%
  rename(city_id = GEOID)

ntx_zcta <- tigris::zctas(state = "TX", year = 2010) %>%
  .[ntx_counties, ] %>%
  select(ZCTA5CE10, geometry) %>%
  rename(zip_id = ZCTA5CE10)

ntx_districts <- st_read("data/geographies/all_school_boundaries.geojson") %>%
  st_transform(crs = 4269)
  

#### Functions to extract the zip code and city name from address strings #####
# extractcity function only does a partial fix of extracting city information.
# requires tableauprep after file has been exported
extractcity <- function(x) {
  str_replace_all(x, "[[:punct:]]", " ") %>%
  str_replace_all(., "[[:digit:]]", " ") %>%
  str_to_title(.) %>%
  str_remove(., "Tx") %>%
  str_squish(.) %>% 
  word(., -1) %>%
  gsub('\\b\\w{1,1}\\b','',.) %>%
  as.character(.)
  
}

extractzip <- function(x) {
  str_replace_all(x, "[[:punct:]]", "") %>%
  str_replace_all(., "[[:alpha:]]", " ") %>%
  str_squish(.) %>%
  word(., -1) %>%
  str_sub(., 1, 5)  
}

#### Eviction data import and attribute selection Collin County #####
#select only the necessary column types and rename them based on NTE data plan
collin <- import("https://evictions.s3.us-east-2.amazonaws.com/collin-county-tx-evictions.rds", trust = TRUE) %>%
#  select(case_number, location, date_filed, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48085",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Precinct ", "48085-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(collin)
#unique(collin$precinct_id)

#### Eviction data import and attribute selection Denton County #####
#select only the necessary column types and rename them based on NTE data plan
denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds", trust = TRUE) %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  filter(!is.na(defendant_address)) %>%
  mutate(county_id = "48121",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Justice of the Peace Pct #", "48121-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(denton)
#unique(denton$precinct_id)

#### Eviction data import and attribute selection Tarrant County #####
#select only the necessary column types and rename them based on NTE data plan
tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv", trust = TRUE) %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48439",
         amount = NA,
         precinct_id = str_replace(precinct_id, "JP No. ", "48439-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(tarrant)
#unique(tarrant$precinct_id)

#### Eviction data import and attribute selection Dallas County #####
#select only the necessary column types and rename them based on NTE data plan
dallas <- import(paste0(libDB, "Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv")) %>%
#  select(case_number, court, df_city, df_zip, filed_date, amount, X, Y) %>%
  select(case_number, court, df_city, df_zip, filed_date, amount, X, Y, plaintiff_name, pl_address) %>%
  rename(date = filed_date,
         city_id = df_city,
         zip_id = df_zip,
         precinct_id = court,
         plaintiff_address = pl_address,
         lon = X,
         lat = Y) %>%
  mutate(county_id = "48113",
         subprecinct_id = str_replace(precinct_id, "Court ", "48113-"),
         precinct_id = substr(subprecinct_id, 1, nchar(subprecinct_id)-2),
         city_id = str_to_title(city_id),
         date = lubridate::as_date(date, format = "%m/%d/%Y"),
         zip_id = as.character(zip_id))

#names(dallas)
#unique(dallas$precinct_id)

#### Join all county data into singular dataframe #####
# join all county datasets into one main dataset
evictioncases <- full_join(full_join(full_join(dallas, collin), denton), tarrant) %>%
  relocate(case_number, date, amount, precinct_id, city_id, county_id, lon, lat) %>%
  mutate(city_id = ifelse(city_id == "", NA, 
                          ifelse(city_id == " ", NA, city_id))) %>%
  select(-plaintiff_address, -plaintiff_name)

#### Extract all cases without lon/lat coordinates available #####
eviction_NA <- evictioncases %>%
  filter(is.na(city_id)) %>%
  filter(is.na(lon))

# REVIEW HOW MANY NA IF ANY COUNTIES ARE EXPERIENCING HIGH NA VALUES IN COORDINATES
evictioncases %>%
  mutate(year = lubridate::year(date)) %>%
  filter(year >= 2016) %>%
  group_by(county_id, year) %>%
  summarize(
    total_count = n(),
    na_count = sum(is.na(lon)),
    na_percentage = (na_count / total_count)) %>%
  ungroup() %>%
  select(-na_count, -total_count) %>%
  pivot_wider(names_from = county_id, values_from = c(na_percentage)) %>%
  arrange(year)

#### Replace all incorrect/missing city names with NA #####
city_small <- ntx_places %>%
  st_drop_geometry(.)

#### Create sf frame of all cases containing lon/lat coordinates #####
eviction_sf <- evictioncases %>%
  filter(!is.na(city_id)) %>%
  filter(!is.na(lon)) %>%
#  mutate(city_id = sapply(city_id, 
#                           function(x){agrep(x, 
#                                             ntx_places$NAME, 
#                                             value = TRUE)}),
#         city_id = city_replace(city_id)
#         ) %>%

  st_as_sf(coords = c("lon", "lat"), crs = 4269) %>%
  st_transform(crs = 4269) %>%
  mutate(lon = sf::st_coordinates(.)[,1],
         lat = sf::st_coordinates(.)[,2]) %>%
  st_join(., ntx_places, left = TRUE) %>%
  mutate(
    city_id.x = case_when(
      city_id.x == "Worth"         ~ "Fort Worth",
      city_id.x == "city"          ~ NA_character_,
      city_id.x == "Nv"            ~ NA_character_,
      city_id.x == "Orlando"       ~ NA_character_,
      city_id.x == "Paul"          ~ "St. Paul",
      city_id.x == "Point"         ~ NA_character_,
      city_id.x == "Piont"         ~ NA_character_,
      city_id.x == "Crossroads"    ~ "Cross Roads",
      city_id.x == "Roads"         ~ "Cross Roads",
      city_id.x == "Road"          ~ "Cross Roads",
      city_id.x == "Mckinney"      ~ "McKinney",
      city_id.x == "Ridge"         ~ "Blue Ridge",
      city_id.x == "City"          ~ NA_character_,
      city_id.x == "Elm"           ~ "Little Elm",
      city_id.x == "Copeville"     ~ "Colleyville",
      city_id.x == "Colony"        ~ "The Colony",
      city_id.x == "Circlesanger"  ~ "Sanger",
      city_id.x == "Lewsiville"    ~ "Lewisville",
      TRUE                         ~ city_id.x
    ),
    city_id.z = ifelse(!is.na(NAME), NAME, city_id.x)
  ) %>%
  select(-city_id.x, -city_id.y, -NAME, -zip_id) %>%
  rename(NAME = city_id.z) %>%
  left_join(., city_small, by = "NAME") %>%
  st_join(., ntx_zcta) %>%
  .[ntx_counties, ]

#### Import tract geographies from tigris package #####
ntx_tracts <- tigris::tracts(state = "TX", county = counties, year = 2020) %>%
  select(GEOID, geometry) %>%
  rename(tract_id = GEOID)

#### Import council districts geographies #####
dallascouncil <- st_read(paste0(libDB, "Data Library/City of Dallas/02_Boundaries and Features/Legislative Boundaries/City Council 2023 Boundaries/Council_Simple.shp")) %>%
  mutate(DISTRICT = str_pad(DISTRICT, 2, pad = "0"),
         council_id = paste0("4819000-", DISTRICT)) %>%
  select(council_id, geometry) %>%
  st_transform(crs = 4269)

#### Import school district boundaries geographies #####
eviction_elem <- st_read("data/geographies/elem_boundaries.geojson") %>%
  rename(elem_id = unique_id) %>%
  select(elem_id, geometry) %>%
  st_transform(crs = 4269)

eviction_midd <- st_read("data/geographies/mid_boundaries.geojson") %>%
  rename(midd_id = unique_id) %>%
  select(midd_id, geometry) %>%
  st_transform(crs = 4269) %>%
  st_make_valid()

eviction_high <- st_read("data/geographies/high_boundaries.geojson") %>%
  rename(high_id = unique_id) %>%
  select(high_id, geometry) %>%
  st_transform(crs = 4269) 

# Eviction data geography attribute  columns ##########
eviction_export <- eviction_sf %>%
  .[ntx_counties, ] %>%
  st_join(., ntx_tracts) %>%
  st_join(., dallascouncil) %>%
  st_join(., eviction_elem) %>%
  st_join(., eviction_midd) %>%
  st_join(., eviction_high) %>%
  relocate(case_number, date, amount, precinct_id, subprecinct_id, council_id, tract_id, zip_id, city_id, county_id, elem_id, midd_id, high_id, lon, lat) %>%
  st_drop_geometry(.) %>%
  full_join(., eviction_NA) %>%
  filter(date >= as.Date("2017-01-01"))
  

# Data export to repo folder #####
eviction_export %>%
  select(-NAME) %>%
  export(., "data/NTEP_eviction_cases.csv")

eviction_export %>%
  select(-NAME) %>%
  export(., "filing data/NTEP_eviction_cases.csv")

# Data Prep for Long and Wide Format Export#####
long_city <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(NAME, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
            ) %>%
  rename(city_id = NAME) %>%
  filter(!is.na(city_id)) %>%
  rename(NAME = city_id) %>%
  mutate(Geography = "City")

long_precinct <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(precinct_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(precinct_id)) %>%
  rename(NAME = precinct_id) %>%
  mutate(Geography = "Precinct")

long_council <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(council_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(council_id)) %>%
  rename(NAME = council_id) %>%
  mutate(Geography = "City Council")

long_tract <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(tract_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(tract_id)) %>%
  rename(NAME = tract_id) %>%
  mutate(Geography = "Census Tract")

long_zip <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(zip_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(zip_id)) %>%
  rename(NAME = zip_id) %>%
  mutate(Geography = "Zip")

long_county <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(county_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(county_id)) %>%
  rename(NAME = county_id) %>%
  mutate(Geography = "County")

long_elem <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(elem_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(elem_id)) %>%
  rename(NAME = elem_id) %>%
  mutate(Geography = "Elementary School")

long_midd <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(midd_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(midd_id)) %>%
  rename(NAME = midd_id) %>%
  mutate(Geography = "Middle School")

long_high <- eviction_export %>%
  mutate(amount = ifelse(amount == 0, NA, amount),
         year = lubridate::year(date),
         month = lubridate::month(date)) %>%
  group_by(high_id, year, month) %>%
  summarise(tot_evic = n(),
            med_amount = median(amount, na.rm = TRUE),
            mean_amount = mean(amount, na.rm = TRUE)
  ) %>%
  filter(!is.na(high_id)) %>%
  rename(NAME = high_id) %>%
  mutate(Geography = "High School")

long_export <- rbind(long_city, long_council) %>%
  rbind(., long_elem) %>%
  rbind(., long_midd) %>%
  rbind(., long_high) %>%
  rbind(., long_county) %>%
  rbind(., long_precinct) %>%
  rbind(., long_tract) %>%
  rbind(., long_zip) %>%
  rename(Name = NAME,
         Year = year,
         Month = month) %>%
  select(Name, Geography, Year, Month, tot_evic, med_amount, mean_amount) %>%
  filter(Name != "")
  
wide_export <- long_export %>%
  pivot_longer(cols = c(tot_evic, med_amount, mean_amount), 
               names_to = "Metric") %>%
  pivot_wider(names_from = Name,
              values_from = value)

export(long_export, "filing data/NTEP_datadownload.csv")
export(wide_export, "filing data/NTEP_datadownload_wide.csv")

