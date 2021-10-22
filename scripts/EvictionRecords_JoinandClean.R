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

ntx_zcta <- tigris::zctas(state = "TX", year = 2010) %>%
  .[ntx_counties, ] %>%
  select(ZCTA5CE10, geometry) %>%
  rename(zip_id = ZCTA5CE10)

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
collin <- import("https://evictions.s3.us-east-2.amazonaws.com/collin-county-tx-evictions.rds") %>%
  select(case_number, location, date_filed, lon, lat, defendant_address) %>%
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
denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds") %>%
  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
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
tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv") %>%
  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
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
dallas <- import("E:/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
  select(case_number, court, df_city, df_zip, filed_date, amount, X, Y) %>%
  rename(date = filed_date,
         city_id = df_city,
         zip_id = df_zip,
         precinct_id = court,
         lon = X,
         lat = Y) %>%
  mutate(county_id = "48113",
         precinct_id = str_replace(precinct_id, "Court  ", "48113-"),
         city_id = str_to_title(city_id),
         date = lubridate::as_date(date),
         zip_id = as.character(zip_id))

#names(dallas)
#unique(dallas$precinct_id)

#### Join all county data into singular dataframe #####
# join all county datasets into one main dataset
evictioncases <- full_join(full_join(full_join(dallas, collin), denton), tarrant) %>%
  relocate(case_number, date, amount, precinct_id, city_id, county_id, lon, lat) %>%
  mutate(city_id = ifelse(city_id == "", NA, 
                          ifelse(city_id == " ", NA, city_id)))

#### Extract all cases without lon/lat coordinates available #####
eviction_NA <- evictioncases %>%
  filter(is.na(city_id)) %>%
  filter(is.na(lon))

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
  mutate(city_id.x = ifelse(city_id.x == "Worth", "Fort Worth", 
                            ifelse(city_id.x == "city", NA, 
                                   ifelse(city_id.x == "Nv", NA,
                                          ifelse(city_id.x == "Orlando", NA,
                                                 ifelse(city_id.x == "Paul", "St. Paul",
                                                        ifelse(city_id.x == "Point", NA,
                                                               ifelse(city_id.x == "Piont", NA, 
                                                                      ifelse(city_id.x == "Crossroads", "Cross Roads", 
                                                                             ifelse(city_id.x == "Roads", "Cross Roads",
                                                                                    ifelse(city_id.x == "Road", "Cross Roads",
                                                                                           ifelse(city_id.x == "Mckinney", "McKinney",
                                                                                                  ifelse(city_id.x == "Ridge", "Blue Ridge",
                                                                                                         ifelse(city_id.x == "City", NA,
                                                                                                                ifelse(city_id.x == "Elm", "Little Elm",
                                                                                                                       ifelse(city_id.x == "Copeville", "Colleyville",
                                                                                                                              ifelse(city_id.x == "Colony", "The Colony",
                                                                                                                                     ifelse(city_id.x == "Circlesanger", "Sanger",
                                                                                                                                            ifelse(city_id.x == "Lewsiville", "Lewisville", city_id.x)))))))))))))))))),
         city_id.z = ifelse(!is.na(NAME), NAME, city_id.x)) %>%
  select(-city_id.x, -city_id.y, -NAME, -zip_id) %>%
  rename(NAME = city_id.z) %>%
  left_join(., city_small, by = "NAME") %>%
  st_join(., ntx_zcta) %>%
  .[ntx_counties, ]

#### Import tract geographies from tigris package #####
ntx_tracts <- tigris::tracts(state = "TX", county = counties) %>%
  select(GEOID, geometry) %>%
  rename(tract_id = GEOID)

#### Import council districts geographies #####
dallascouncil <- st_read("E:/CPAL Dropbox/Data Library/City of Dallas/02_Boundaries and Features/Legislative Boundaries/Council_Simple.shp") %>%
  mutate(DISTRICT = str_pad(DISTRICT, 2, pad = "0"),
         council_id = paste0("4819000-", DISTRICT)) %>%
  select(council_id, geometry) %>%
  st_transform(crs = 4269)

#### Import JP Precincts geographies #####
jp_courts <- st_read("demo/NTEP_demographics_jpcourt.geojson") %>%
  transmute(jpcourt_id = id) %>%
  st_transform(crs = 4269)

plot(jp_courts["geometry"])

# Eviction data geography attribute  columns ##########
eviction_export <- eviction_sf %>%
  .[ntx_counties, ] %>%
  st_join(., ntx_tracts) %>%
  st_join(., dallascouncil) %>%
#  st_join(., jp_courts) %>%
  relocate(case_number, date, amount, precinct_id, council_id, tract_id, zip_id, city_id, county_id, lon, lat) %>% #jpcourt_id
  select(-NAME) %>%
  st_drop_geometry(.) %>%
  full_join(., eviction_NA)

# Data export to repo folder #####
export(eviction_export, "filing data/NTEP_eviction_cases.csv")

eviction_export %>%
  filter(date >= as.Date("2020-03-01")) %>%
  mutate(week = lubridate::floor_date(date, unit = "week")) %>%
  group_by(county_id, week) %>%
  summarize(count = n()) %>%
  ggplot( aes(x=week, y=count, group=county_id, color=county_id)) +
  geom_line(size = 1) +
  scale_x_date(date_breaks  = "2 month", date_minor_breaks = "1 month", date_labels = "%b %y")

