library(sf)
library(tidyverse)
library(stringr)

# Specify folder where boundaries are stored
school_bound_directory <- "data/boundaries"

boundary_files <- list.files(school_bound_directory, pattern = "\\.(geojson|shp)$", full.names = TRUE)

#Specify column names to pull 
columns_to_pull <- c("SchoolName", "SchoolCode", "geometry", "SLN", "ELEM_DESC", "HIGH", "MIDDLE", "HIGH_SLN", "MID_SLN")

# Make place for files to go
processed_geojsons <- list()

# Loop through each file, subset columns, and add a unique identifier
for (i in seq_along(boundary_files)) {
  
  geojson_data <- st_read(boundary_files[i])
  
  # Extract the filename and split into sections based on "_". Needs to start with "District_Type_" ex "DISD_Middle_Boundaries" 
  file_name <- basename(boundary_files[i])
  file_sections <- str_split_fixed(file_name, "_", 3)
  file_prefix <- tolower(file_sections[, 1])
  
  # Map file_type to specified codes based on school type
  file_type <- case_when(
    file_sections[, 2] == "Elementary" ~ "-01-",
    file_sections[, 2] == "Middle" ~ "-02-",
    file_sections[, 2] == "High" ~ "-03-",
    TRUE ~ file_sections[, 2]  # Default to original if not one of these types
  )
  
  # Add NAs to fill gaps caused by different column names between data sets
  missing_columns <- setdiff(columns_to_pull, names(geojson_data))
  geojson_data[missing_columns] <- NA
  
  # Select only needed columns
  geojson_data <- geojson_data %>% select(all_of(columns_to_pull))
  
  # Merge columns together (different names in data sets), Add unique ID for school 
  geojson_data <- geojson_data %>%
    mutate(
      District = file_prefix,
      SchoolType = file_type,
      SLN = coalesce(SLN, SchoolCode, HIGH_SLN, MID_SLN),
      SchoolName = coalesce(SchoolName, HIGH, MIDDLE, ELEM_DESC)) %>%
  mutate(unique_id = paste0(District, SchoolType, SLN)) 
  
  # Add the processed data to the list
  processed_geojsons[[i]] <- geojson_data
}

# Merge into one dataset
merged_data <- do.call(rbind, processed_geojsons)

merged_data <- st_cast(merged_data, "MULTIPOLYGON")

# Get rid of uneeded columns
boundary_final <- merged_data %>%
  select(1,11,12)

st_write(boundary_final, "data/all_school_boundaries.geojson", delete_dsn = TRUE)

elem_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "01"))

st_write(elem_bounds, "data/NTEP_demo_elem_boundaries.geojson", delete_dsn = TRUE)

high_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "03"))

st_write(high_bounds, "data/NTEP_demo_high_boundaries.geojson", delete_dsn = TRUE)

mid_bounds <- boundary_final %>%
  filter(str_detect(unique_id, "02"))

st_write(mid_bounds, "data/NTEP_demo_mid_boundaries.geojson", delete_dsn = TRUE)




