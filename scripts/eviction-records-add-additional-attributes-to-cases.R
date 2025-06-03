# Setup and Import ----------------------------------------
library(tidyverse)
library(tigris)
library(rio)
library(sf)
library(lubridate)
library(scales)
library(janitor)
options(scipen = 999)


EvictionMaster <- import("Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
  filter(!is.na(X), !is.na(Y))

# Tigris Polygons ----------------------------------------
#create sf objects for various geography types within and surrounding Dallas County
#including tracts, zcta, place, county, and others
DallasCounty_sf <- counties("TX") %>%
  filter(GEOID == 48113) %>%
  st_transform(crs = 4326) %>%
  select(GEOID, geometry)

TexasTracts20_sf <- tracts("TX", year = 2020) %>%
  st_transform(crs = 4326) %>%
  select(NAMELSAD, GEOID, geometry) %>%
  rename(GEOID_2020 = GEOID,
         NAME_2020 = NAMELSAD)

TexasTracts10_sf <- tracts("TX", year = 2010) %>%
  st_transform(crs = 4326) %>%
  select(NAMELSAD10, GEOID10, geometry) %>%
  rename(GEOID_2010 = GEOID10,
         NAME_2010 = NAMELSAD10)

#convert current eviction records with geocodes into an sf frame
Eviction_sf <- EvictionMaster %>%
  st_as_sf(., coords = c(x = "X", y = "Y"), crs = 4326) %>%
  .[DallasCounty_sf, ]

#plot(Eviction_sf["amount"], breaks = "fisher")

# EvictionLab Upload ----------------------------------------

#Adjust data for evictionlab share
EvictionLab <- Eviction_sf %>%
  st_join(., TexasTracts20_sf) %>%
  st_join(., TexasTracts10_sf) %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2],
         zip = df_zip) %>%
#  select(-lat_short, -lon_short, -amount) %>%
  filter(lat != 0) %>%
  st_drop_geometry(.)

names(EvictionLab)

##### Join Weekly Records Together #####
EvictionMaster <- import("Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
  filter(!is.na(X), !is.na(Y)) %>%
  mutate(filed_date = as.Date(filed_date, format = c("%m/%d/%Y")),
#         judgment_date = as.Date(judgment_date, format = c("%m/%d/%Y")),
         appearance_date = as.character(appearance_date),
         pl_phone = as.character(pl_phone),
         amount = as.character(amount),
         monthly_rent = as.character(monthly_rent),
         amount_filed = as.character(amount_filed))
#str(EvictionMaster)
#names(EvictionMaster)
  
##### Export to Github #####
export(EvictionLab, "/Users/anushachowdhury/Documents/GitHub/dallas-county-eviction-filing/DallasCounty_EvictionRecords.csv")
# export(EvictionLab, "C:/Users/taylo/Documents/GitHub/dallas-county-eviction-filing/DallasCounty_EvictionRecords.csv")
#
# dates2024 <- EvictionMaster%>%
#   filter(lubridate::year(filed_date) == 2024)%>%
#   group_by(filed_date)%>%
#   summarise(n = n())
# library(highcharter)
# dates2024Chart <-#highchart() %>% 
#   hchart(dates2024, "line", hcaes(x = filed_date, y = n)) %>%
#   hc_xAxis(type='datetime', title=NULL) %>% 
#   hc_yAxis(title = 'Visits', min =0)%>%
#   #hc_colors(palette_cpal_main) %>%
#   hc_title(text='Monthly Title X Family Planning Visits Receiving LARC')
# dates2024Chart
