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
  mutate(unique_id = paste0("1-disd-", SLN)) %>%
  select(schoolname,geometry,unique_id)

disd_mid <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/Middle_Attendance_Boundaries.shp")) %>%
  select(MID_SLN, MIDDLE, geometry) %>%
  rename(schoolname = MIDDLE,
         SLN = MID_SLN) %>%
  st_transform(4269) %>%
  mutate(unique_id = paste0("2-disd-", SLN)) %>%
  select(schoolname,geometry,unique_id)

 disd_high <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/High_Attendance_Boundaries.geojson")) %>%  
  select(HIGH_SLN, HIGH, geometry) %>%
  rename(schoolname = HIGH,
         SLN = HIGH_SLN) %>%
   st_transform(4269) %>%
   mutate(unique_id = paste0("3-disd-", SLN)) %>%
   select(schoolname,geometry,unique_id)

##### School District: RISD #####
risd_elem <- st_read(paste0(libDB, "Data Library/Richardson Independent School District/School Boundaries/Richardson ISD Elementary School Boundaries 2024-2025.geojson")) %>%  
  select(SchoolCode, SchoolName, geometry) %>%
  rename(schoolname = SchoolName,
         SLN = SchoolCode) %>%
   mutate(unique_id = paste0("1-risd-", SLN)) %>%
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
     unique_id = paste0("2-risd-", SLN)
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
  mutate(unique_id = paste0("3-risd-", SLN)) %>%
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
    id = paste0("9-ntx-", str_pad(as.numeric(interaction(SDLEA)), width = 3, pad = "0"))
    
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
  filter(str_detect(unique_id, "1-|9-ntx-"))

plot(elem_bounds["unique_id"])

st_write(elem_bounds, "data/geographies/elem_boundaries.geojson", delete_dsn = TRUE)

mid_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "2-|9-ntx-"))

plot(mid_bounds["unique_id"])

st_write(mid_bounds, "data/geographies/mid_boundaries.geojson", delete_dsn = TRUE)

high_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "3-|9-ntx-"))

plot(high_bounds["unique_id"])

st_write(high_bounds, "data/geographies/high_boundaries.geojson", delete_dsn = TRUE)


