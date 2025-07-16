# Arguments:
#
# Environment (*=required, ?=optional, []=default):
#  ? ENV: [development]|production
#  ? R_CONFIG_FILE: [./config.yml] Influenced by value of ENV
#
# Files (RO=read only, RW=read/write, WO=write only):
#  RO R_CONFIG_FILE: a YAML configuration file (see 'config' R package)
#  RW config.data.root
#
options(warn = -1)  # Turn off warnings globally
suppressPackageStartupMessages({
  library(tidyverse)
  library(rio)
  library(sf)
})

print("Libraries loaded")
source('scripts/init.R')
print("Init script sourced")

# Create references to all pertinent directories and files.
data_dir <- list(
  demo = dpath('demo'),
  bubble = dpath('bubble'),
  filing = dpath('filing data'),
  geographies = dpath('geographies')
)
print("Data directory paths set")
project_init_dirs(data_dir)
print("Project directories initialized")

ntep_long <- file.path(data_dir$filing, "NTEP_datadownload.csv")
ntep_wide <- file.path(data_dir$filing, "NTEP_datadownload_wide.csv")

eviction_cases_file_name <- "NTEP_eviction_cases.csv"
print("NTEP CSV file paths set")


ntep_counties <- file.path(data_dir$demo, "NTEP_demographics_county.geojson")
ntep_places <- file.path(data_dir$demo, "NTEP_demographics_place.geojson")
ntep_zcta <- file.path(data_dir$demo, "NTEP_demographics_zip.geojson")
ntep_tracts <- file.path(data_dir$demo, "NTEP_demographics_tract.geojson")
ntep_council <- file.path(data_dir$demo, "NTEP_demographics_council.geojson")
print("Demographic GeoJSON paths set")

ntep_elem <- file.path(data_dir$geographies, "elem_boundaries.geojson") # future us review why for the school boundaries we're pulling data from a different file name structure than other geography types.
ntep_midd <- file.path(data_dir$geographies, "mid_boundaries.geojson")
ntep_high <- file.path(data_dir$geographies, "high_boundaries.geojson")
print("School boundary file paths set")

evictiondata <- config$data$evictions # sources for raw datasets
print("Eviction config loaded")

#### Generate dataframes with geometries #####
counties <- c("Dallas County",
              "Collin County",
              "Denton County",
              "Tarrant County")

ntx_counties <- st_read(ntep_counties, quiet = TRUE) %>%
  select(name, id, geometry) %>%
  mutate(NAME = str_remove(name, " County, Texas")) %>%
  select(NAME, id,  geometry) %>%
  rename(county_id = id)
print("County geometries loaded")

ntx_places <- st_read(ntep_places, quiet = TRUE) %>%
  select(name, id, geometry) %>%
  rename(city_id = id,
         NAME = name) %>%
  mutate(NAME = str_remove(NAME, ", Texas"))
print("City and town geometry loaded")

ntx_zcta <- st_read(ntep_zcta, quiet = TRUE) %>%
  select(id, geometry) %>%
  rename(zip_id = id)
print("Zip code geometry loaded")

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
collin <- import(evictiondata$collin, trust = TRUE) %>%
#  select(case_number, location, date_filed, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48085",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Precinct ", "48085-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address),
         subprecinct_id = NA) %>%
  select(-defendant_address)

#names(collin)
cat("Unique Collin County Precinct IDs:", paste(unique(collin$precinct_id), collapse = ", "), "\n")

#### Eviction data import and attribute selection Denton County #####
#select only the necessary column types and rename them based on NTE data plan
denton <- import(evictiondata$denton, trust = TRUE) %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
#  filter(!is.na(defendant_address)) %>%
  mutate(county_id = "48121",
         amount = NA,
         precinct_id = str_replace(precinct_id, "Justice of the Peace Pct #", "48121-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address),
         subprecinct_id = NA) %>%
  select(-defendant_address)

#names(denton)
cat("Unique Denton County Precinct IDs:", paste(unique(denton$precinct_id), collapse = ", "), "\n")

#### Eviction data import and attribute selection Tarrant County #####
#select only the necessary column types and rename them based on NTE data plan
tarrant <- import(evictiondata$tarrant, trust = TRUE) %>%
#  select(case_number, date_filed, location, lon, lat, defendant_address) %>%
  select(case_number, date_filed, location, lon, lat, defendant_address, plaintiff_name, plaintiff_address) %>%
  rename(precinct_id = location,
         date = date_filed) %>%
  mutate(county_id = "48439",
         amount = NA,
         precinct_id = str_replace(precinct_id, "JP No. ", "48439-"),
         date = lubridate::as_date(date),
         zip_id = extractzip(defendant_address),
         city_id = extractcity(defendant_address),
         subprecinct_id = NA) %>%
  select(-defendant_address)

#names(tarrant)
cat("Unique Tarrant County Precinct IDs:", paste(unique(tarrant$precinct_id), collapse = ", "), "\n")

#### Eviction data import and attribute selection Dallas County #####
#select only the necessary column types and rename them based on NTE data plan
dallas <- import(project_file$master$daily$csv) %>%
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
cat("Unique Dallas County Precinct IDs:", paste(unique(dallas$precinct_id), collapse = ", "), "\n")

#### Join all county data into singular dataframe #####
# join all county datasets into one main dataset
dallas %>%
  filter(!is.na(date)) %>%
  mutate(year = lubridate::year(date)) %>%
  count(year) %>%
  arrange(year) %>%
  knitr::kable(caption = "Dallas County Evictions by Year")

evictioncases <- evictioncases <- bind_rows(dallas, collin, denton, tarrant) %>%
  relocate(case_number, date, amount, precinct_id, city_id, county_id, lon, lat) %>%
  mutate(city_id = ifelse(city_id == "", NA, 
                          ifelse(city_id == " ", NA, city_id))) %>%
  select(-plaintiff_address, -plaintiff_name)

# Summary table of case counts by county
evictioncases %>%
  count(county_id, name = "case_count") %>%
  arrange(desc(case_count)) %>%
  knitr::kable(caption = "Number of Eviction Cases by County")

print(
  evictioncases %>%
    filter(date == Sys.Date() - 1) %>%
    summarise(new_cases = n()) %>%
    pull(new_cases) %>%
    paste("Total number of new eviction cases from yesterday:", .)
)

print(
  evictioncases %>%
    filter(date == max(date, na.rm = TRUE)) %>%
    summarise(new_cases = n(),
              latest_date = max(date, na.rm = TRUE)) %>%
    mutate(message = paste("Total number of new eviction cases from most recent date", latest_date, ":", new_cases)) %>%
    pull(message)
)

# 
# evictioncases %>%
#   filter(county_id == "48113") %>%
#   group_by(lubridate::year(date)) %>%
#   summarize(count = n())


#### Replace all incorrect/missing city names with NA #####
city_small <- ntx_places %>%
  st_drop_geometry(.)

#### Extract all cases without lon/lat coordinates available #####
eviction_NA <- evictioncases %>%
  filter(is.na(lon)) %>%
  mutate(elem_id = NA,
         midd_id = NA,
         high_id = NA,
         council_id = NA,
         ntx_tracts = NA) %>%
  mutate(
    city_id = case_when(
      city_id == "Worth"         ~ "Fort Worth",
      city_id == "city"          ~ NA_character_,
      city_id == "Nv"            ~ NA_character_,
      city_id == "Orlando"       ~ NA_character_,
      city_id == "Paul"          ~ "St. Paul",
      city_id == "Point"         ~ NA_character_,
      city_id == "Piont"         ~ NA_character_,
      city_id == "Crossroads"    ~ "Cross Roads",
      city_id == "Roads"         ~ "Cross Roads",
      city_id == "Road"          ~ "Cross Roads",
      city_id == "Mckinney"      ~ "McKinney",
      city_id == "Ridge"         ~ "Blue Ridge",
      city_id == "City"          ~ NA_character_,
      city_id == "Elm"           ~ "Little Elm",
      city_id == "Copeville"     ~ "Colleyville",
      city_id == "Colony"        ~ "The Colony",
      city_id == "Circlesanger"  ~ "Sanger",
      city_id == "Lewsiville"    ~ "Lewisville",
      city_id == "Messquite"     ~ "Mesquite",
      city_id == "North Dallas"     ~ "Dallas",
      city_id == "Sasche"     ~ "Sachse",
      city_id == "Mesqute"     ~ "Mesquite",
      city_id == "Sesoto"     ~ "Desoto",
      city_id == "Wimer"     ~ "Wilmer",
      city_id == "Wills Point"     ~ "Willis Point",
      city_id == "Kinney"     ~ "McKinney",
      city_id == "Dakkas"     ~ "Dallas",
      city_id == "Plno"     ~ "Plano",
      city_id == "Dalla"     ~ "Dallas",
      city_id == "Pllano"     ~ "Plano",
      city_id == "Frosco"     ~ "Frisco",
      city_id == "Frscio"     ~ "Frisco",
      city_id == "Friscot"     ~ "Frisco",
      city_id == "Friso"     ~ "Frisco",
      city_id == "Firsco"     ~ "Frisco",
      city_id == "Frsico"     ~ "Frisco",
      city_id == "Richardxson"     ~ "Richardson",
      city_id == "Ricahrdson"     ~ "Richardson",
      city_id == "Wtlie"     ~ "Wylie",
      city_id == "Mckiney"     ~ "McKinney",
      city_id == "Mckinnwy"     ~ "McKinney",
      city_id == "Mckinneyt"     ~ "McKinney",
      city_id == "Plaono"     ~ "Plano",
      city_id == "Alllen"     ~ "Allen",
      city_id == "Mckinneyt"     ~ "McKinney",
      city_id == "Mckinnwy"     ~ "McKinney",
      city_id == "Sacshe"     ~ "Sachse",
      city_id == "Frirso"     ~ "Frisco",
      city_id == "Plan"     ~ "Plano",
      city_id == "Princton"     ~ "Princeton",
      city_id == "Ricardson"     ~ "Richardson",
      city_id == "Princenton"     ~ "Princeton",
      city_id == "Mckininey"     ~ "McKinney",
      city_id == "Alen"     ~ "Allen",
      city_id == "Dalls"     ~ "Dallas",
      city_id == "Palno"     ~ "Plano",
      city_id == "Fariview"     ~ "Fairview",
      city_id == "Planop"     ~ "Plano",
      city_id == "Propser"     ~ "Prosper",
      city_id == "Frisc"     ~ "Frisco",
      city_id == "Cross Roads "     ~ "Cross Roads",
      city_id == "Ftw"     ~ "Fort Worth",
      city_id == "Mansfiedl"     ~ "Mansfield",
      city_id == "Northlake "     ~ "Northlake",
      city_id == "Ponder "     ~ "Ponder",
      city_id == "Prosper "     ~ "Prosper",
      city_id == "Savannah"     ~ "Savannah CDP",
      city_id == "New Fairview"     ~ "Fairview",
      city_id == "View"     ~ "Fairview",
      city_id == "Branch"     ~ "Farmers Branch",
      city_id == "Christi"     ~ "Corpus Christi",
      city_id == "Mound"     ~ "Flower Mound",
      city_id == "Rddallas"     ~ "Dallas",
      city_id == "Oak"     ~ "Red Oak",
      city_id == "Avedallas"     ~ "Dallas",
      city_id == "Gdallas"     ~ "Dallas",
      city_id == "Stdallas"     ~ "Dallas",
      city_id == "Prairie"     ~ "Grand Prairie",
      city_id == "Weateford"     ~ "Weatherford",
      city_id == "Alington"     ~ "Arlington",
      city_id == "Lake"     ~ "Southlake",
      
      city_id == "NA" ~ NA,
      
      
      TRUE                         ~ city_id
    )
  ) %>%
  rename(NAME = city_id) %>%
  left_join(., city_small, by = "NAME") %>%
  mutate(NAME = trimws(NAME))

# REVIEW HOW MANY NA IF ANY COUNTIES ARE EXPERIENCING HIGH NA VALUES IN COORDINATES
evictioncases %>%
  mutate(year = lubridate::year(date)) %>%
  filter(year >= 2016) %>%
  group_by(county_id, year) %>%
  summarize(
    total_count = n(),
    na_count = sum(is.na(lon)),
    na_percentage = (na_count / total_count)) %>%
  knitr::kable(caption = "Percentage of Eviction Cases Missing Coordinates by County and Year")

#### Create sf frame of all cases containing lon/lat coordinates #####
eviction_sf <- evictioncases %>%
  filter(!is.na(lon)) %>%
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
      city_id.x == "Messquite"     ~ "Mesquite",
      city_id.x == "North Dallas"     ~ "Dallas",
      city_id.x == "Sasche"     ~ "Sachse",
      city_id.x == "Mesqute"     ~ "Mesquite",
      city_id.x == "Sesoto"     ~ "Desoto",
      city_id.x == "Wimer"     ~ "Wilmer",
      city_id.x == "Wills Point"     ~ "Willis Point",
      city_id.x == "Kinney"     ~ "McKinney",
      city_id.x == "Dakkas"     ~ "Dallas",
      city_id.x == "Plno"     ~ "Plano",
      city_id.x == "Dalla"     ~ "Dallas",
      city_id.x == "Pllano"     ~ "Plano",
      city_id.x == "Frosco"     ~ "Frisco",
      city_id.x == "Frscio"     ~ "Frisco",
      city_id.x == "Friscot"     ~ "Frisco",
      city_id.x == "Friso"     ~ "Frisco",
      city_id.x == "Firsco"     ~ "Frisco",
      city_id.x == "Frsico"     ~ "Frisco",
      city_id.x == "Richardxson"     ~ "Richardson",
      city_id.x == "Ricahrdson"     ~ "Richardson",
      city_id.x == "Wtlie"     ~ "Wylie",
      city_id.x == "Mckiney"     ~ "McKinney",
      city_id.x == "Mckinnwy"     ~ "McKinney",
      city_id.x == "Mckinneyt"     ~ "McKinney",
      city_id.x == "Plaono"     ~ "Plano",
      city_id.x == "Alllen"     ~ "Allen",
      city_id.x == "Mckinneyt"     ~ "McKinney",
      city_id.x == "Mckinnwy"     ~ "McKinney",
      city_id.x == "Sacshe"     ~ "Sachse",
      city_id.x == "Frirso"     ~ "Frisco",
      city_id.x == "Plan"     ~ "Plano",
      city_id.x == "Princton"     ~ "Princeton",
      city_id.x == "Ricardson"     ~ "Richardson",
      city_id.x == "Princenton"     ~ "Princeton",
      city_id.x == "Mckininey"     ~ "McKinney",
      city_id.x == "Alen"     ~ "Allen",
      city_id.x == "Dalls"     ~ "Dallas",
      city_id.x == "Palno"     ~ "Plano",
      city_id.x == "Fariview"     ~ "Fairview",
      city_id.x == "Planop"     ~ "Plano",
      city_id.x == "Propser"     ~ "Prosper",
      city_id.x == "Frisc"     ~ "Frisco",
      city_id.x == "Cross Roads "     ~ "Cross Roads",
      city_id.x == "Ftw"     ~ "Fort Worth",
      city_id.x == "Mansfiedl"     ~ "Mansfield",
      city_id.x == "Northlake "     ~ "Northlake",
      city_id.x == "Ponder "     ~ "Ponder",
      city_id.x == "Prosper "     ~ "Prosper",
      city_id.x == "Savannah"     ~ "Savannah CDP",
      city_id.x == "New Fairview"     ~ "Fairview",
      city_id.x == "View"     ~ "Fairview",
      
      TRUE                         ~ city_id.x
    ),
    city_id.z = ifelse(!is.na(NAME), NAME, city_id.x)
  ) %>%
  select(-city_id.x, -city_id.y, -NAME, -zip_id) %>%
  rename(NAME = city_id.z) %>%
  left_join(., city_small, by = "NAME") %>%
  st_join(., ntx_zcta) %>%
  mutate(NAME = trimws(NAME))

#### Import tract geographies from tigris package #####
ntx_tracts <- st_read(ntep_tracts) %>%
  select(id) %>%
  rename(tract_id = id)
print('Tract geographies imported')

#### Import council districts geographies #####
dallascouncil <- st_read(ntep_council) %>%
  select(id, geometry) %>%
  rename(council_id = id) %>%
  st_transform(crs = 4269)
print('Council district geographies imported')

#### Import school district boundaries geographies #####
eviction_elem <- st_read(ntep_elem) %>%
  rename(elem_id = unique_id) %>%
  select(elem_id, geometry) %>%
  st_transform(crs = 4269) %>%
  st_make_valid()

eviction_midd <- st_read(ntep_midd) %>%
  rename(midd_id = unique_id) %>%
  select(midd_id, geometry) %>%
  st_transform(crs = 4269) %>%
  st_make_valid()

eviction_high <- st_read(ntep_high) %>%
  rename(high_id = unique_id) %>%
  select(high_id, geometry) %>%
  st_transform(crs = 4269) %>%
  st_make_valid()
print('Elementary, middle, high school geographies imported')

# Eviction data geography attribute  columns ##########
eviction_export <- eviction_sf %>%
  st_join(., ntx_tracts) %>%
  st_join(., dallascouncil) %>%
  st_join(., eviction_elem) %>%
  st_join(., eviction_midd) %>%
  st_join(., eviction_high) %>%
  relocate(case_number, date, amount, precinct_id, subprecinct_id, council_id, tract_id, zip_id, city_id, county_id, elem_id, midd_id, high_id, lon, lat) %>%
  st_drop_geometry(.) %>%
  bind_rows(., eviction_NA) %>%
  mutate(zip_id = str_sub(zip_id, 1, 5)) %>%
  filter(date >= as.Date("2017-01-01"))
print('Eviction data joined to tract, council, and school boundaries')

eviction_export %>%
  filter(county_id == "48113") %>%
  group_by(year = lubridate::year(date)) %>%
  summarize(count = n()) %>%
  knitr::kable(caption = 'Number of Cases by Year for Dallas County')

# Data export to repo folder #####
eviction_export %>%
  select(-NAME, -ntx_tracts) %>%
  export(., dpath(eviction_cases_file_name))
print('Eviction data exported to repo folder')

file.copy(from = dpath(eviction_cases_file_name), 
          to = file.path(data_dir$filing, eviction_cases_file_name),
          overwrite = TRUE)

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

export(long_export, ntep_long)
export(wide_export, ntep_wide)
print('Long and wide data exported')

