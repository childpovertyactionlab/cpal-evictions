library(sf)
library(tidyverse)
library(stringr)
library(rlang)

libDB <- "C:/Users/erose/CPAL Dropbox/"
##### unique_id function #####

add_unique_id <- function(data, prefix, file_path) {
  # Determine the suffix based on the type of school in the file path
  suffix <- case_when(
    grepl("elementary", file_path, ignore.case = TRUE) ~ "-01-",
    grepl("middle", file_path, ignore.case = TRUE) ~ "-02-",
    grepl("high", file_path, ignore.case = TRUE) ~ "-03-",
    TRUE ~ NA_character_
  )
  
  # Add the unique_id column using the specified format
  data <- data %>%
    mutate(unique_id = paste0(prefix, suffix, SLN))
  
  return(data)
}
##### School District: DISD #####

disd_elem <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/Elementary_Attendance_Boundaries.geojson")
) %>%  
  select(SLN, ELEM_DESC, geometry) %>%
  rename(schoolname = ELEM_DESC) %>%
  st_transform(4269) %>%
  mutate(unique_id = paste0("disd-01-", SLN)) %>%
  select(schoolname,geometry,unique_id)

disd_mid <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/Middle_Attendance_Boundaries.shp")) %>%
  select(MID_SLN, MIDDLE, geometry) %>%
  rename(schoolname = MIDDLE,
         SLN = MID_SLN) %>%
  st_transform(4269) %>%
  mutate(unique_id = paste0("disd-02-", SLN)) %>%
  select(schoolname,geometry,unique_id)

 disd_high <- st_read(paste0(libDB, "Data Library/Dallas Independent School District/2024_2025 School Year/High_Attendance_Boundaries.geojson")) %>%  
  select(HIGH_SLN, HIGH, geometry) %>%
  rename(schoolname = HIGH,
         SLN = HIGH_SLN) %>%
  st_transform(4269) %>%
   mutate(unique_id = paste0("disd-03-", SLN)) %>%
   select(schoolname,geometry,unique_id)

##### School District: RISD #####
risd_elem <- st_read(paste0(libDB, "Data Library/Richardson Independent School District/School Boundaries/Richardson ISD Elementary School Boundaries 2024-2025.geojson")) %>%  
  select(SchoolCode, SchoolName, geometry) %>%
  rename(schoolname = SchoolName,
         SLN = SchoolCode) %>%
   mutate(unique_id = paste0("risd-01-", SLN)) %>%
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
     unique_id = paste0("risd-02-", SLN)
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
  mutate(unique_id = paste0("risd-03-", SLN)) %>%
  st_make_valid() %>%  # Ensure geometries are valid before grouping
  group_by(schoolname, unique_id) %>%
  summarise(geometry = st_union(geometry), .groups = "drop") %>%  # Union geometries by unique_id
  st_cast("MULTIPOLYGON") %>%  # Cast to MULTIPOLYGON to ensure consistency
  st_transform(4269) %>%  # Transform to desired CRS
  select(schoolname, geometry, unique_id)


##### Make list of DFs and bind #####
list_of_dfs <- mget(ls(pattern = "elem|mid|high")) 

print(names(list_of_dfs))

boundary_final <- do.call(rbind, list_of_dfs) %>%
  st_cast("MULTIPOLYGON")


##### Save merged boundary files #####
st_write(boundary_final, "data/all_school_boundaries.geojson", delete_dsn = TRUE)

elem_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "-01-"))

st_write(elem_bounds, "data/elem_boundaries.geojson", delete_dsn = TRUE)

high_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "-03-"))

st_write(high_bounds, "data/high_boundaries.geojson", delete_dsn = TRUE)

mid_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "-02-"))

st_write(mid_bounds, "data/mid_boundaries.geojson", delete_dsn = TRUE)
