library(sf)
library(tidyverse)
library(stringr)
library(rlang)

#libDB <- "C:/Users/erose/CPAL Dropbox/"
libDB <- "C:/Users/Michael/CPAL Dropbox/"

##### School District: DISD #####

disd_elem <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/Elementary_Attendance_Boundaries.geojson")
) %>%  
  select(SLN, ELEM_DESC, geometry) %>%
  rename(schoolname = ELEM_DESC) %>%
  st_transform(4269) %>%
  mutate(unique_id = paste0("01-disd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0"))) %>%
  select(schoolname,geometry,unique_id)

disd_mid <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/Middle_Attendance_Boundaries.shp")) %>%
  select(MID_SLN, MIDDLE, geometry) %>%
  rename(schoolname = MIDDLE,
         SLN = MID_SLN) %>%
  st_transform(4269) %>%
  mutate(unique_id = paste0("02-disd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0"))) %>%
  select(schoolname,geometry,unique_id)

disd_high <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/High_Attendance_Boundaries.geojson")) %>%  
  select(HIGH_SLN, HIGH, geometry) %>%
  rename(schoolname = HIGH,
         SLN = HIGH_SLN) %>%
   st_transform(4269) %>%
   mutate(unique_id = paste0("03-disd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0"))) %>%
   select(schoolname,geometry,unique_id)

##### School District: RISD #####
risd_elem <- st_read(paste0(libDB, "Data Library/Richardson Independent School District/School Boundaries/Richardson ISD Elementary School Boundaries 2024-2025.geojson")) %>%  
  select(SchoolCode, SchoolName, geometry) %>%
  rename(schoolname = SchoolName,
         SLN = SchoolCode) %>%
   mutate(unique_id = paste0("01-risd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0")),
          schoolname = ifelse(schoolname == "Arapaho Classical Magnet/Mohawk", "Arapaho Classical Magnet", schoolname)) %>%
   st_make_valid() %>%  # Ensure geometries are valid before grouping
   group_by(unique_id, schoolname) %>%
   summarise(geometry = st_union(geometry), .groups = "drop") %>%  # Union geometries by unique_id
   st_cast("MULTIPOLYGON") %>%  # Cast to MULTIPOLYGON to ensure consistency
   st_transform(4269) %>%  # Transform to desired CRS
   select(schoolname, geometry, unique_id)

 risd_mid <- st_read(paste0(libDB, "Data Library/Richardson Independent School District/School Boundaries/Richardson ISD Middle School Boundaries 2024-2025.geojson")) %>%  
   select(SchoolCode, SchoolName, geometry) %>%
   rename(schoolname = SchoolName, SLN = SchoolCode) %>%
   mutate(
     schoolname = str_trim(schoolname),  # Trim any extra spaces
     unique_id = paste0("02-risd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0"))
   ) %>%
   st_make_valid() %>%  # Ensure geometries are valid before grouping
   group_by(schoolname, unique_id) %>%
   summarise(geometry = st_union(geometry), .groups = "drop") %>%  # Union geometries by unique_id
   st_cast("MULTIPOLYGON") %>%  # Cast to MULTIPOLYGON to ensure consistency
   st_transform(4269) %>%  # Transform to desired CRS
   select(schoolname, geometry, unique_id)

risd_high <- st_read(paste0(libDB, "Data Library/Richardson Independent School District/School Boundaries/Richardson ISD High School Boundaries 2024-2025.geojson")) %>%
  select(SchoolCode, SchoolName, geometry) %>%
  rename(schoolname = SchoolName, SLN = SchoolCode) %>%
  mutate(unique_id = paste0("03-risd-", str_pad(as.numeric(interaction(SLN)), width = 6, pad = "0"))) %>%
  st_make_valid() %>%  # Ensure geometries are valid before grouping
  group_by(schoolname, unique_id) %>%
  summarise(geometry = st_union(geometry), .groups = "drop") %>%  # Union geometries by unique_id
  st_cast("MULTIPOLYGON") %>%  # Cast to MULTIPOLYGON to ensure consistency
  st_transform(4269) %>%  # Transform to desired CRS
  select(schoolname, geometry, unique_id)

##### Import All NTX School ISD Boundaries and bind missing ISD boundaries to individual school level data
counties <- c("Dallas County", 
              "Collin County", 
              "Denton County", 
              "Tarrant County")

ntx_counties <- tigris::counties(state = "TX") %>%
  filter(NAMELSAD %in% counties)

districts <- st_read("data/geographies/Current_Districts_2023.geojson")

ntx_districts <- districts %>%
  st_make_valid() %>%
  st_filter(ntx_counties %>% st_transform(st_crs(districts))) %>%
  filter(NAME != "Dallas ISD",
         NAME != "Richardson ISD") %>%
  mutate(
    id = paste0("09-notx-", str_pad(as.numeric(interaction(SDLEA)), width = 6, pad = "0"))
  ) %>% 
  select(unique_id = id, 
         schoolname = NAME, 
         geometry) %>%
  st_transform(crs = 4269)

##### Make list of DFs and bind #####
list_of_dfs <- mget(ls(pattern = "elem|mid|high")) 

print(names(list_of_dfs))

boundary_final <- do.call(rbind, list_of_dfs) %>%
  st_cast("MULTIPOLYGON") %>%
  rbind(., ntx_districts)

#plot(boundary_final["unique_id"])

##### Save merged boundary files #####
st_write(boundary_final, "data/geographies/all_school_boundaries.geojson", delete_dsn = TRUE)

elem_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "01-|09-notx-")) %>%
  mutate(unique_id = str_replace(unique_id, "9-n0tx-00", "9-notx-01"))

plot(elem_bounds["unique_id"])

st_write(elem_bounds, "data/geographies/elem_boundaries.geojson", delete_dsn = TRUE)

mid_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "02-|09-notx-")) %>%
  mutate(unique_id = str_replace(unique_id, "09-notx-00", "09-notx-02"))

plot(mid_bounds["unique_id"])

st_write(mid_bounds, "data/geographies/mid_boundaries.geojson", delete_dsn = TRUE)

high_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "03-|09-notx-")) %>%
  mutate(unique_id = str_replace(unique_id, "09-notx-00", "09-notx-03"))

plot(high_bounds["unique_id"])

st_write(high_bounds, "data/geographies/high_boundaries.geojson", delete_dsn = TRUE)


