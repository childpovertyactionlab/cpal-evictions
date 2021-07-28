library(tidyverse)
library(rio)
library(sf)

########## Eviction data import and attribute selection ##########
#import eviction data across all counties
#select only the necessary column types and rename them based on NTE data plan
collin <- import("https://evictions.s3.us-east-2.amazonaws.com/collin-county-tx-evictions.rds") %>%
  select(case_number, location, date_filed, lon, lat) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "Collin",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Precinct", "Collin County Precinct "),
         date = lubridate::as_date(date))

#names(collin)
#unique(collin$precinct_id)

denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds") %>%
  select(case_number, date_filed, location, lon, lat) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "Denton",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Justice of the Peace Pct #", "Denton County Precinct "),
         date = lubridate::as_date(date))

#names(denton)
#unique(denton$precinct_id)

tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv") %>%
  select(case_number, date_filed, location, lon, lat) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "Tarrant",
         amount = NA,
         precinct_id = str_replace(precinct_id, "JP No.", "Tarrant County Precinct"),
         date = lubridate::as_date(date))

#names(tarrant)
#unique(tarrant$precinct_id)

dallas <- import(here::here("filing data", "raw data", "DallasCounty_EvictionRecords_Master.csv")) %>%
  select(case_number, court, df_city, filed_date, amount, X, Y) %>%
  rename(date = filed_date,
         city_id = df_city,
         precinct_id = court,
         lon = X,
         lat = Y) %>%
  mutate(county_id = "Dallas",
         precinct_id = str_replace(precinct_id, "Court ", "Dallas County Precinct"),
         city_id = str_to_title(city_id),
         date = lubridate::as_date(date))

#names(dallas)
#unique(dallas$precinct_id)


########## Eviction data county join ##########
evictioncases <- full_join(full_join(full_join(dallas, collin), denton), tarrant) %>%
  relocate(case_number, date, amount, precinct_id, city_id, county_id, lon, lat)

evictioncases_NA <- evictioncases %>%
  filter(is.na(lon))

evictioncases_sf <- evictioncases %>%
  filter(!is.na(lon)) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4269) %>%
  st_transform(crs = "ESRI:102738")

########## Import geographies from tigris package ##########
counties <- c("Dallas County",
              "Collin County",
              "Denton County",
              "Tarrant County")

ntx_counties <- tigris::counties(state = "TX") %>%
  filter(NAMELSAD %in% counties) %>%
  select(NAME, geometry) %>%
  rename(county_id = NAME) %>%
  st_transform(crs = "ESRI:102738")

ntx_places <- tigris::places(state = "TX") %>%
  st_transform(crs = "ESRI:102738") %>%
  .[ntx_counties, ] %>%
  select(NAME, geometry) %>%
  rename(city_id = NAME)

ntx_zcta <- tigris::zctas(starts_with = c("75", "76")) %>%
  st_transform(crs = "ESRI:102738") %>%
  .[ntx_counties, ] %>%
  select(ZCTA5CE10, geometry) %>%
  rename(zip_id = ZCTA5CE10)

ntx_tracts <- tigris::tracts(state = "TX", county = counties) %>%
  st_transform(crs = "ESRI:102738") %>%
  select(NAME, geometry) %>%
  rename(tract_id = NAME)

########## Eviction data geography attribute columns ##########
evictioncases_final <- evictioncases_sf %>%
  .[ntx_counties, ] %>%
  st_join(., ntx_tracts) %>%
  st_join(., ntx_places) %>%
  st_join(., ntx_zcta) %>%
  mutate(city_id = ifelse(!is.na(city_id.x), city_id.x, city_id.y), #for dallas county only
         lat = st_coordinates(.)[,1],
         lon = st_coordinates(.)[,2]) #%>%
  relocate(case_number, date, amount, precinct_id, tract_id, zip_id, city_id, county_id, lon, lat) %>%
  as.data.frame(.) %>%
  select(-city_id.x, -city_id.y, geometry) %>%
  full_join(., evictioncases_NA)

plot(evictioncases_final["city_id"])

library(leaflet)
cpal_style <- "https://api.mapbox.com/styles/v1/owencpal/ckecb71jp22ct19qc1id28jku/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoib3dlbmNwYWwiLCJhIjoiY2tlYnR3emdxMGNhZzMwb2EzZWR4ajloNCJ9.P7Mujz8F3Rssq5-Q6dcvMw"
map_attr <- "© <a href='https://www.mapbox.com/map-feedback/'>Mapbox</a> Basemap © <a href='https://childpovertyactionlab.org/'>Child Poverty Action Lab</a>"

test <- evictioncases_final %>%
  st_transform(crs = 4269) %>%
  filter(is.na(city_id))

testcity <- ntx_places %>%
  st_transform(crs = 4269)

testcounty <- ntx_counties %>%
  st_transform(crs = 4269)

leaflet() %>%
  setView(lng = -96.7970, lat = 32.7767, zoom = 10) %>%
  addTiles(urlTemplate = cpal_style, attribution = map_attr) %>%
  addPolygons(data = testcounty,
              color = "red",
              weight = 10,
              fillOpacity = 0) %>%
    addPolygons(data = testcity,
              color = "teal",
              fillColor = "gray",
              weight = 2,
              fillOpacity = 0.6) %>%
  addCircleMarkers(data = test,
                   radius = 4,
                   stroke = FALSE,
                   fillColor = "magenta",
                   popup = paste0("<b>", "City: ", "</b>", test$city_id))

########## Data export