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

#### Eviction data import and attribute selection Collin County #####
#select only the necessary column types and rename them based on NTE data plan
collin <- import("https://evictions.s3.us-east-2.amazonaws.com/collin-county-tx-evictions.rds") %>%
#  select(case_number, location, date_filed, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_name, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48085",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Precinct ", "48085-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address))

#names(collin)
#unique(collin$precinct_id)

#### Eviction data import and attribute selection Denton County #####
#select only the necessary column types and rename them based on NTE data plan
denton <- import("https://evictions.s3.us-east-2.amazonaws.com/denton-county-tx-evictions.rds") %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_name, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  filter(!is.na(defendant_address)) %>%
  mutate(county_id = "48121",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Justice of the Peace Pct #", "48121-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address))

#names(denton)
#unique(denton$precinct_id)

#### Eviction data import and attribute selection Tarrant County #####
#select only the necessary column types and rename them based on NTE data plan
tarrant <- import("https://evictions.s3.us-east-2.amazonaws.com/tarrant-evictions-2020.csv") %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_name, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48439",
         amount = NA,
         precinct_id = str_replace(precinct_id, "JP No. ", "48439-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address))

#names(tarrant)
#unique(tarrant$precinct_id)

#### Eviction data import and attribute selection Dallas County #####
#select only the necessary column types and rename them based on NTE data plan
#dallas <- import("C:/Users/micha/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
dallas <- import("E:/CPAL Dropbox/Data Library/Dallas County/Eviction Records/Data/Dallas County Eviction Master/EvictionRecords_Master.csv") %>%
#  select(case_number, court, df_city, df_zip, filed_date, amount, X, Y) %>%
  select(case_number, court, df_city, df_zip, defendant_name, df_address, filed_date, amount, X, Y, plaintiff_name, pl_address) %>%
  rename(date = filed_date,
         city_id = df_city,
         zip_id = df_zip,
         precinct_id = court,
         plaintiff_address = pl_address,
         defendant_address = df_address,
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
                          ifelse(city_id == " ", NA, city_id)))

dallascity <- evictioncases %>%
  filter(city_id == "Dallas")

dallascity %>%
  group_by(county_id) %>%
  summarise(count = n(),
            mindate = min(date, na.rm = TRUE))

rio::export(dallascity, "E:/CPAL Dropbox/Analytics/04_Projects/External Requests/City of Dallas  Project Support/Evictions City Hall/Data/Eviction Filings City of Dallas 01012017-03152022.csv")
