library(tidyverse)
library(sf)


# function to import and rbind all the jm49 files together
import_jm49_files <- function(folder_path) {
  # Get list of xlsx files starting with JM49
  files <- list.files(path = folder_path, pattern = "^JM49.*\\.xlsx$", full.names = TRUE)
  
  # Stop if no matching files found
  if (length(files) == 0) {
    stop("No files starting with 'JM49' were found in the specified folder.")
  }
  
  # Read and bind all files
  all_data <- do.call(rbind, lapply(files, rio::import, stringsAsFactors = FALSE))
  
  return(all_data)
}

# new
jm49daily <- import_jm49_files('data/ORR Data')
jm49daily %>% group_by(year = lubridate::year(FILE_DATE)) %>% summarise(n = n())%>% janitor::adorn_totals() %>%
  knitr::kable(caption = "ORR Evictions by Year")
# current
master <- rio::import('data/EvictionRecords_Master.csv') %>%
  rename(CASE_NUMBER = case_number)
master %>% group_by(year = lubridate::year(filed_date)) %>% summarise(n = n())%>% janitor::adorn_totals() %>%
  knitr::kable(caption = "Current Evictions by Year")

print(paste0("Number of cases in new data: ", format(nrow(jm49daily), big.mark =',')))
print(paste0("Number of cases in old data: ", format(nrow(master), big.mark =',')))
print(paste0("Difference: ", format(nrow(master)-nrow(jm49daily), big.mark = ',')))

# anti join for those that exist in orr but not master
anti <- jm49daily %>%
  mutate(CASE_NUMBER = if_else(str_starts(CASE_NUMBER, "JE"),
                               str_remove(CASE_NUMBER, "^JE"),
                               CASE_NUMBER)) %>%
  anti_join(master, by = "CASE_NUMBER")
print(paste0("Number of case numbers not present in Master: ", format(nrow(anti), big.mark= ',')))

# duplicates
jm49dupCaseNum <- jm49daily %>%
  group_by(CASE_NUMBER) %>%
  summarise(n = n())
jm49dup<- jm49daily %>%
  group_by(across(everything())) %>%
  filter(n() > 1) %>%
  ungroup()
print(paste0('Number of duplicate cases in new data: ', nrow(jm49dup)))




# downloading 75216 for emily
# oakcliff <- tigris::zctas(year = 2020, class = 'sf') %>%
#   filter(ZCTA5CE20 == '75216')
# st_write(oakcliff, 'data/75216 Boundary.geojson')

# doing it manually just to double check
# jm49_17 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2017.xlsx')
# jm49_18 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2018.xlsx')
# jm49_19 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2019.xlsx')
# jm49_20 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2020.xlsx')
# jm49_21 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2021.xlsx')
# jm49_22 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2022.xlsx')
# jm49_23 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2023.xlsx')
# jm49_24 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2024.xlsx')
# jm49_25 <- rio::import('data/ORR Data/JM49_Eviction_Daily_2025_Till_06_10.xlsx')
# jm49 <- rbind(jm49_17, jm49_18, jm49_19, jm49_20, jm49_21, jm49_22, jm49_23, jm49_24, jm49_25)