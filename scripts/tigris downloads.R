library(tidyverse)
library(tigris)
library(sf)

counties <- c("Dallas County",
              "Collin County",
              "Denton County",
              "Tarrant County")
countySf <- counties(state = 'TX') %>%
  filter(NAME %in% gsub(" County", "", counties)) %>%
  st_transform(crs = 4326)

tracts2020 <- tracts(state = 'TX',
                 year = 2020,
                 county = counties)
st_write(tracts2020, 'data/geographies/2020 Census Tracts.geojson')
# plot(tracts2020)

tracts2010 <- tracts(state = 'TX',
                     year = 2010,
                     county = counties)
st_write(tracts2020, 'data/geographies/2010 Census Tracts.geojson')
# plot(tracts2010)

places2020 <- places(state = 'TX',
                     year = 2020) %>%
  st_transform(crs = 4326) %>%
  st_intersection(countySf)
st_write(tracts2020, 'data/geographies/2020 Places.geojson')
# plot(places2020)
# 
# places2010 <- places(state = 'TX',
#                      year = 2010)%>%
#   st_transform(crs = 4326) %>%
#   st_intersection(countySf)

# testing census tract appending
master <- read.csv('/Users/anushachowdhury/Downloads/EvictionRecords_Master.csv') %>%
  filter(!is.na(X) & !is.na(Y)) %>%  # Remove rows with missing coordinates
  st_as_sf(coords = c("X", "Y"), crs = 4326, remove = FALSE)

tracts10 <- st_read('data/geographies/2010 Census Tracts.geojson', quiet = TRUE) %>%
  select(GEOID) %>%
  rename(tract10 = GEOID)%>%
  st_transform(crs = st_crs(master)) %>%
  st_join(master)
tracts20 <-st_read('data/geographies/2020 Census Tracts.geojson', quiet = TRUE)%>%
  select(GEOID) %>%
  rename(tract20 = GEOID) %>%
  st_transform(crs = st_crs(master))%>%
  st_join(tracts10)
