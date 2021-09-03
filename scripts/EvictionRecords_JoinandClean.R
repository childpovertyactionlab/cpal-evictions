#### Load necessary libraries #####
library(tidyverse)
library(rio)
library(sf)

#### Generate dataframes with geometries #####
counties <- c("Dallas County",
              "Collin County",
              "Denton County",
              "Tarrant County")

ntx_counties <- tigris::counties(state = "TX") %>%
  filter(NAMELSAD %in% counties) %>%
  select(NAME, GEOID,  geometry) %>%
  rename(county_id = GEOID)

ntx_places <- tigris::places(state = "TX") %>%
  .[ntx_counties, ] %>%
  select(NAME, GEOID, geometry) %>%
  rename(city_id = GEOID)

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

# Eviction data import and attribute selection #####
#import eviction data across all counties
#select only the necessary column types and rename them based on NTE data plan
collin <- import("https://evictions.s3.us-east-2.amazonaws.com/collin-county-tx-evictions.rds") %>%
  select(case_number, location, date_filed, lon, lat, defendant_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "Collin",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Precinct", "Collin County Precinct "),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(collin)
#unique(collin$precinct_id)

denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds") %>%
  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  filter(!is.na(defendant_address)) %>%
  mutate(county_id = "Denton",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Justice of the Peace Pct #", "Denton County Precinct "),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(denton)
#unique(denton$precinct_id)

tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv") %>%
  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "Tarrant",
         amount = NA,
         precinct_id = str_replace(precinct_id, "JP No.", "Tarrant County Precinct"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address)) %>%
  select(-defendant_address)

#names(tarrant)
#unique(tarrant$precinct_id)

dallas <- import("E:/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/DallasCounty_EvictionRecords_Master.csv") %>%
  select(case_number, court, df_city, df_zip, filed_date, amount, X, Y) %>%
  rename(date = filed_date,
         city_id = df_city,
         zip_id = df_zip,
         precinct_id = court,
         lon = X,
         lat = Y) %>%
  mutate(county_id = "Dallas",
         precinct_id = str_replace(precinct_id, "Court ", "Dallas County Precinct"),
         city_id = str_to_title(city_id),
         date = lubridate::as_date(date),
         zip_id = as.character(zip_id))

#names(dallas)
#unique(dallas$precinct_id)

# Eviction data county join #####
# join all county datasets into one main dataset
evictioncases <- full_join(full_join(full_join(dallas, collin), denton), tarrant) %>%
  relocate(case_number, date, amount, precinct_id, city_id, county_id, lon, lat) %>%
  mutate(city_id = ifelse(city_id == "", NA, 
                          ifelse(city_id == " ", NA, city_id)))

# generate dataframe of only cases without lon/lat data
eviction_NA <- evictioncases %>%
  filter(is.na(city_id)) %>%
  filter(is.na(lon))

#function to replace incorrect places names with NA
city_replace <- function(x) {
  as.character(x) %>%
    ifelse(str_detect(., '(', NA, .))
}

#council districts
dallascouncil <- st_read("E:/CPAL Dropbox/Data Library/City of Dallas/02_Boundaries and Features/Council_Simple.shp") %>%
  select(DISTRICT, geometry) %>%
  rename(council_id = DISTRICT) %>%
  mutate(council_id = paste("Council District", council_id)) %>%
  st_transform(crs = 4269)

#create sf of all cases with lon/lat data
eviction_sf <- evictioncases %>%
  filter(!is.na(city_id)) %>%
  filter(!is.na(lon)) %>%
  mutate(city_id = sapply(city_id, 
                           function(x){agrep(x, 
                                             ntx_places$city_id, 
                                             value = TRUE)}),
         city_id = city_replace(city_id)) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4269) %>%
  st_transform(crs = 4269) %>%
  mutate(lon = sf::st_coordinates(.)[,1],
         lat = sf::st_coordinates(.)[,2]) %>%
  st_join(., dallascouncil, left = TRUE)

# Import geographies from tigris package #####
ntx_tracts <- tigris::tracts(state = "TX", county = counties) %>%
  select(NAMELSAD, geometry) %>%
  rename(tract_id = NAMELSAD)

# Eviction data geography attribute  columns ##########
eviction_export <- eviction_sf %>%
  .[ntx_counties, ] %>%
  st_join(., ntx_tracts) %>%
  relocate(case_number, date, amount, precinct_id, tract_id, zip_id, city_id, county_id, lon, lat) %>%
  as.data.frame(.) %>%
  select(-geometry) %>%
  full_join(., eviction_NA)

# Data export to repo folder #####
export(eviction_export, "filing data/NTEP_eviction_cases.csv")
