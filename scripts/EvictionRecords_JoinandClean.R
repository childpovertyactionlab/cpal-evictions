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
denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds") %>%
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
tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv") %>%
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
dallas <- import("C:/Users/micha/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
#dallas <- import("E:/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
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
         subprecinct_id = str_replace(precinct_id, "Court  ", "48113-"),
         precinct_id = substr(subprecinct_id, 1, nchar(subprecinct_id)-2),
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
                          ifelse(city_id == " ", NA, city_id))) %>%
  select(-plaintiff_address, -plaintiff_name)

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
#dallascouncil <- st_read("E:/CPAL Dropbox/Data Library/City of Dallas/02_Boundaries and Features/Legislative Boundaries/Council_Simple.shp") %>%
dallascouncil <- st_read("C:/Users/micha/CPAL Dropbox/Data Library/City of Dallas/02_Boundaries and Features/Legislative Boundaries/Council_Simple.shp") %>%
  mutate(DISTRICT = str_pad(DISTRICT, 2, pad = "0"),
         council_id = paste0("4819000-", DISTRICT)) %>%
  select(council_id, geometry) %>%
  st_transform(crs = 4269)

# Eviction data geography attribute  columns ##########
eviction_export <- eviction_sf %>%
  .[ntx_counties, ] %>%
  st_join(., ntx_tracts) %>%
  st_join(., dallascouncil) %>%
  relocate(case_number, date, amount, precinct_id, subprecinct_id, council_id, tract_id, zip_id, city_id, county_id, lon, lat) %>%
  st_drop_geometry(.) %>%
  full_join(., eviction_NA)

# Data export to repo folder #####
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

long_export <- rbind(long_city, long_council) %>%
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
#export(wide_export, "filing data/NTEP_datadownload_wide.csv")

#### TESTING CODE #####
eviction_export %>%
  filter(date >= as.Date("2020-03-01")) %>%
  mutate(week = lubridate::floor_date(date, unit = "week")) %>%
  group_by(county_id, week) %>%
  summarize(count = n()) %>%
  ggplot( aes(x=week, y=count, group=county_id, color=county_id)) +
  geom_line(size = 1) +
  scale_x_date(date_breaks  = "2 month", date_minor_breaks = "1 month", date_labels = "%b %y")

topfilers <- eviction_sf %>%
  st_drop_geometry(.) %>%
  filter(date >= as.Date("2020-03-01") &
           date <= as.Date("2021-09-30")) %>%
  filter(NAME == "Dallas") %>%
  group_by(plaintiff_name, plaintiff_address) %>%
  summarize(count = n()) %>%
  arrange(desc(count)) %>%
  ungroup(.) %>%
  slice(1:20)

test <- eviction_sf %>%
  select(plaintiff_name, plaintiff_address, lat, lon) %>%
  st_drop_geometry(.) %>%
  left_join(topfilers, .) %>%
  group_by(plaintiff_name, plaintiff_address, count) %>%
  slice(1:1)

topfilers_final <- groupname %>%
  group_by(plaintiff_name, plaintiff_address) %>%
  summarise(count = sum(count)) %>%
  left_join(., eviction_sf) %>%
  group_by(plaintiff_name, plaintiff_address, count) %>%
  slice(1:1) %>%
  select(plaintiff_name, plaintiff_address, count, geometry) %>%
  ungroup(.) %>%
  slice(1:10)

st_write(topfilers_final, "C:/Users/micha/CPAL Dropbox/Living Wage Jobs/04_Projects/Eviction Top Filers/Data/TopEvictionFilers.gpkg", layer = "Top 10 Filers", delete_layer = TRUE)

topfilers_final %>%
  export(., "C:/Users/micha/CPAL Dropbox/Living Wage Jobs/04_Projects/Eviction Top Filers/Data/Top10EvictionFilers.csv")
