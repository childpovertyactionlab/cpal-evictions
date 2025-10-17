# Arguments:
#
# Environment (*=required, ?=optional, []=default):
#  * GOOGLE_APPLICATION_CREDENTIALS: email|path/to/Google/Workspace/service-account/JSON
#  ? ENV: [development]|production
#  ? R_CONFIG_FILE: [./config.yml] Influenced by value of ENV
#
# Files (RO=read only, RW=read/write, WO=write only):
#  RO R_CONFIG_FILE: a YAML configuration file (see 'config' R package)
#  RW config.data.root
#

library(tidyverse)
library(rio)
library(sf)
library(lubridate)
library(scales)
library(janitor)
library(googlesheets4)
library(stringdist)
library(arrow) # parquet
library(readxl)

source('scripts/init.R')

if (env_prod()) {
  options(gargle_oauth_cache = FALSE)
  options(gargle_verbosity = 'info')
} else {
  options(gargle_verbosity = 'debug')
}

# Copy a file from the DCAD source into 'to' (see file.copy for 'to' behavior).
# Error is the source file does not exist or the copy cannot be completed.
# If the destination file already exists, it will be overwritten.
dcad_fetch <- function (from, to) {
  dcad_srv_data = config$dcad$dest
  if (!file.exists(file.path(dcad_srv_data, from))) {
    stop(paste(file.path(dcad_srv_data, from), "does not exist"))
  }
  copy_result <- tryCatch({
    file.copy(
      from = file.path(dcad_srv_data, from),
      to,
      overwrite = TRUE
    )
  }, error = function(e) {
    e$message
  })
  if (is.character(copy_result) || !copy_result) {
    stop(paste("failed to copy", file.path(dcad_srv_data, from), '->', to), copy_result)
  }
  return(TRUE)
}
# List all files from the DCAD source.
dcad_list <- function () {
  return(list.files(config$dcad$dest))
}

# Create references to all pertinent directories and files.
data_dir <- list(
  daily = dpath('Dallas County Daily Eviction Reports'),
  weekly = dpath('Dallas County Weekly Eviction Reports')
)
data_dir$dailyArchive <- file.path(data_dir$daily, "archive")
data_dir$weeklyArchive <- file.path(data_dir$weekly, "archive")
project_init_dirs(data_dir)

reviewGeoFile <- file.path(project_dir$master, "EvictionRecords_ReviewandGeocode.csv")

sheets <- list(
  report = config$sheet$report
)

# Functions for place name cleaning
find_closest_match <- function(vec, reference, threshold = NULL) { 
  
  vec <- gsub("[^A-Za-z]", "", str_squish(toupper(vec)))
  
  # Check for NA or numeric entries
  is_na_or_numeric <- is.na(vec) | grepl("^[0-9]+$", vec)
  
  # Compute distances only for valid entries
  valid_entries <- vec[!is_na_or_numeric]
  distances <- stringdist::stringdistmatrix(valid_entries, reference, method = "lv")
  
  min_distances <- apply(distances, 1, min)
  corrected_indices <- apply(distances, 1, which.min)
  corrected_valid <- reference[unlist(corrected_indices)]
  
  # If minimum distance is greater than threshold, ignore for cities, use original for states
  if(!is.null(threshold)) {
    corrected_valid[min_distances > threshold] <- valid_entries[min_distances > threshold]
  }
  
  # Reassemble results with NA and numeric entries in place
  corrected <- rep(NA, length(vec))
  corrected[!is_na_or_numeric] <- corrected_valid
  
  return(corrected)
}

correct_column <- function(dataframe, colname, reference, threshold = NULL) {
  unique_vals <- unique(dataframe[[colname]])
  corrected_vals <- find_closest_match(unique_vals, reference, threshold)
  lookup <- setNames(corrected_vals, unique_vals)
  
  dataframe[[colname]] <- lookup[dataframe[[colname]]]
  
  return(dataframe)
}

# Download boundary data
options(tigris_protocol = "ftp")
tx_cities <- tigris::places(state="TX")$NAME %>% toupper()
states <- c(state.name, state.abb) %>% toupper()

print(paste0("!! Begin: Pulling data..."))

### DAILY DATA

# Find latest archived file date and calculate missings
archivedDailyFiles <- list.files(path = data_dir$dailyArchive, pattern = "Eviction_Data_Daily_\\d{4}-\\d{2}-\\d{2}", full.names = TRUE)
datesFromDailyFiles <- as.Date(gsub("Eviction_Data_Daily_", "", basename(archivedDailyFiles)), format = "%Y-%m-%d")

tryCatch({

  missingDates <- seq(from = max(datesFromDailyFiles, na.rm = TRUE) + 1, to = lubridate::today() - 1, by = "days")

  for (date in missingDates) {

    # Check what day it is and if a new file needs to be downloaded from Dallas County server,
    dailyDate <- format(as.Date(date), format = "%m%d%Y")

    # string together the file name to be pulled,
    dailyPull <- paste0("JM049_Eviction_Data_Daily_", dailyDate, ".xlsx")
    print(paste0("! Expecting daily file ", dailyPull))

    # pull DCAD file into working directory
    tryCatch({
      if (dcad_fetch(dailyPull, data_dir$daily)) {
        print(paste0("! Got daily file for ", format(as.Date(date), "%d %b")))
      }
    }, error = function(e) {
      message("An error occurred: ", e$message)
    })

  }

}, error = function(e) {
  stop("An error occurred: ", e$message)
})

# if (lubridate::wday(today(), label=TRUE) == "Mon") {
#   ### WEEKLY ### denoted by the Sunday on which it's uploaded
#   dcadWeekly <- dcad_list() %>%
#     filter(str_detect(name, "Weekly"), !t3 %in% 2000:year(today())) %>%
#     ## !!! CORRECT THIS WHEN DCAD FILE TIMESTAMP IS FIXED
#     mutate(
#       year = ifelse(t1 %in% c("Nov", "Dec"), 2023, 2024),
#       date = mdy(paste(t1, t2, year)),
#       writeName = paste0("Eviction_Data_Weekly_", date, ".xls")
#     )
# 
#   archivedWeeklyFiles <- list.files(path = data_dir$weeklyArchive, pattern = "Eviction_Data_Weekly_\\d{4}-\\d{2}-\\d{2}", full.names = TRUE)
#   datesFromWeeklyFiles <- ymd(gsub("Eviction_Data_Weekly_", "", basename(archivedWeeklyFiles)))
#   pullDates <- setdiff(dcadWeekly$date, datesFromWeeklyFiles)
#   
#     
#   for (pullDate in pullDates) {
#     
#     # string together the file name to be pulled,
#     weeklyPull <- dcadWeekly %>%
#       filter(date == pullDate) %>%
#       pull(name)
#     print(paste0("! Expecting weekly file ", weeklyPull))
# 
#     # pull DCAD file into working directory
#     tryCatch({
#       if (dcad_fetch(weeklyPull, data_dir$weekly)) {
#         print(paste0("! Got daily file for ", format(as.Date(date), "%d %b")))
#       }
#     }, error = function(e) {
#       message("An error occurred: ", e$message)
#     })
#     
#   }  
#     
#   weeklyFiles <- list.files(data_dir$weekly, full.names = TRUE, pattern = "Eviction_Data_Weekly_")
#   
#   weeklyJoint <- weeklyFiles %>%
#     keep(~ file.size(.) >= 100000) %>% # ignore small files because they are corrupted
#     map_dfr(~ read_excel (.x) %>%
#               mutate(
#                 `WRIT ISSUED DT` = as.character(`WRIT ISSUED DT`),
#                 `WRIT SERVED DT` = as.character(`WRIT SERVED DT`),
#                 `WRIT RETURNED DT` = as.character(`WRIT RETURNED DT`),
#                 `WRIT RCVD BY CT` = as.character(`WRIT RCVD BY CT`),
#               )
#             )
# 
#   weeklyMaster <- arrow::read_parquet(project_file$master$weekly$parquet) %>%
#     bind_rows(weeklyJoint) %>%
#     distinct(.keep_all = TRUE)
#   
#   arrow::write_parquet(weeklyMaster, project_file$master$weekly$parquet)
#   write_csv(weeklyMaster, project_file$master$weekly$csv)
#   
#   for (weeklyFile in weeklyFiles) {
#     oldName <- basename(weeklyFile)
#     newName <- dcadWeekly %>%
#       filter(name == oldName) %>%
#       pull(writeName)
#     newPath <- file.path(data_dir$weeklyArchive, newName)
#     file.rename(weeklyFile, newPath)
#   }
# }

dailyFiles <- list.files(data_dir$daily, full.names = TRUE, pattern = "JM049_Eviction_Data_Daily_")

valid_files <- c()

# Initialize daily as empty data frame to prevent "object not found" error
daily <- data.frame()

if (length(dailyFiles) > 0) {
  
  for (file in dailyFiles) {
    # Extract the MMDDYYYY part from the new format
    dateFromFile <- gsub("JM049_Eviction_Data_Daily_(\\d+)\\.xlsx", "\\1", basename(file))
    
    # Parse the date components from MMDDYYYY format
    file_month <- as.numeric(substr(dateFromFile, 1, 2))
    file_day <- as.numeric(substr(dateFromFile, 3, 4))
    file_year <- as.numeric(substr(dateFromFile, 5, 8))
    
    # Convert to YYYY-MM-DD format
    date_formatted <- sprintf("%04d-%02d-%02d", file_year, file_month, file_day)
    
    # Define the new archived filename (keeping the old naming convention for consistency)
    archived_filename <- paste0("Eviction_Data_Daily_", date_formatted, ".xlsx")
    archived_filepath <- file.path(data_dir$dailyArchive, archived_filename)
    
    # Rename with standardized format and move to archive
    file.rename(file, archived_filepath)
    
    # Verify the file can be read
    tryCatch(
      {
        readxl::read_xlsx(archived_filepath)  # Changed from read_xls to read_xlsx
        valid_files <- c(valid_files, archived_filepath)
      }, 
      error = function(e){cat("Error importing file", file, "\n")}
    )
  }
  
  ## IMPORT DAILY FILE and clean ##
  daily <- bind_rows(lapply(valid_files, function(file) {
    data <- import(file)
    data$CASE_NUMBER <- as.character(data$CASE_NUMBER)
    data$FILE_DATE <- as.Date(data$FILE_DATE)
    data$PL_LAST_NAME <- as.character(data$PL_LAST_NAME)
    data$PL_FIRST_NAME <- as.character(data$PL_FIRST_NAME)
    data$PL_MIDDLE_NAME <- as.character(data$PL_MIDDLE_NAME)
    data$PLT_ADDRESS <- as.character(data$PLT_ADDRESS)
    data$PL_CITY <- as.character(data$PL_CITY)
    data$PL_STATE <- as.character(data$PL_STATE)
    data$PL_PHONE <- as.character(data$PL_PHONE)
    data$DF_LAST_NAME <- as.character(data$DF_LAST_NAME)
    data$DF_FIRST_NAME <- as.character(data$DF_FIRST_NAME)
    data$DF_MIDDLE_NAME <- as.character(data$DF_MIDDLE_NAME)
    data$APPEAR_DATE <- as.Date(data$APPEAR_DATE)
    data$APPEAR_TIME <- as.character(data$APPEAR_TIME)
    data$NON_PYMNT_RENT_FLG <- as.character(data$NON_PYMNT_RENT_FLG)
    data$PL_ZIP <- as.character(data$PL_ZIP)
    data$DEF_ZIP <- as.character(data$DEF_ZIP)
    return(data)
  })) %>%
    # removing exact duplicates
    distinct(.keep_all = TRUE) %>%
    # multiple defendants
    mutate(
      DEF_FULLNAME = paste(DF_FIRST_NAME, DF_MIDDLE_NAME, DF_LAST_NAME),
      PL_FULLNAME = paste(PL_FIRST_NAME, PL_MIDDLE_NAME, PL_LAST_NAME)
    ) %>%
    group_by(CASE_NUMBER) %>%
    summarise(
      DEF_NAMES = paste(unique(DEF_FULLNAME), collapse = ", "),
      NUM_DEFENDANTS = n_distinct(DEF_FULLNAME),
      PL_NAMES = paste(unique(PL_FULLNAME), collapse = ", "),
      NUM_PLAINTIFFS = n_distinct(PL_FULLNAME),
      across(-c(#DF_FIRST_NAME, DF_MIDDLE_NAME, DF_LAST_NAME,
                #PL_FIRST_NAME, PL_MIDDLE_NAME, PL_LAST_NAME,
                DEF_FULLNAME, PL_FULLNAME),
             ~ first(.x)),  # keep one value from other columns
      .groups = "drop"
    ) %>%
    janitor::clean_names() %>%
    
    # Renaming daily columns to fit master
    rename(
      filed_date = file_date,
      appearance_date = appear_date,
      appearance_time = appear_time,
      non_payment_of_rent = non_pymnt_rent_flg,
      pl_address = plt_address,
      amount = monetary_amount,
      df_phone = def_phone,
      df_zip = def_zip,
      df_address = def_address1,
      df_city = def_city,
      df_state = def_state,
      df_addnum = def_address2
    ) %>%
    
    # Adjusting and consolidating to fit and prepare for master join
    mutate(
      court = str_replace_all(court, "(J-P|JP)", "Court"),
      filed_date = as.Date(filed_date, format = "%m/%d/%Y"),
      appearance_date = lubridate::ymd(str_sub(as.character(appearance_date), 1, 10)),
      amount = str_remove_all(amount, ","),
    ) %>%
    mutate_at(vars(pl_first_name, pl_middle_name, pl_last_name, df_first_name, df_middle_name, df_last_name), ~ifelse(. == "NULL", NA, .)) %>%
    unite("plaintiff_name", pl_first_name, pl_middle_name, pl_last_name, na.rm = TRUE, sep = " ") %>%
    unite("defendant_name", df_first_name, df_middle_name, df_last_name, na.rm = TRUE, sep = " ") %>%
    
    # Cleaning phone numbers, cities, states and other data
    mutate_at(vars(df_phone, pl_phone), ~str_remove_all(., " ")) %>%
    mutate_at(vars(df_phone, pl_phone), ~ifelse(str_ends(., "0000000") | . %in% "0", "Phone Number Not Provided", .)) %>%
    mutate(
      amount_filed = ifelse(amount %in% c(0, 0.00), "Not Non-Payment of Rent", as.character(amount)),
      non_payment_of_rent = NA_character_,
      monthly_rent = NA_character_,
      pl_city = find_closest_match(pl_city, tx_cities, 3),
      pl_state = find_closest_match(pl_state, states),
      df_city = find_closest_match(df_city, tx_cities, 5),
      df_state = find_closest_match(df_state, states)
    ) %>%
    
    # Geocoding
    mutate(df_complete = paste0(df_address, " ", df_city, ", ", df_state, " ", df_zip)) %>%
    tidygeocoder::geocode(address = df_complete,
                          method = "arcgis",
                          full_results = TRUE) %>%
    
    # Remove bad geocodes
    mutate(X = ifelse(score < 96, NA_character_, long),
           Y = ifelse(score < 96, NA_character_, lat))
  
  print(paste0("! Joined new files"))
}

print(paste0("! Moved new files to archive"))


### APPEND DAILIES TO MASTER


# Import master spreadsheet where everything else will be joined to.
# Additional mutates have to occur when importing in order to join with new records.
# Otherwise errors will occur during join.

master <- read_parquet(project_file$master$daily$parquet) %>%
  mutate(across(c(filed_date, appearance_date), as.Date, format = "%m/%d/%Y"),
         across(c(pl_phone, amount, monthly_rent, amount_filed, df_zip, attorney_fee, subsidy_govt), as.character),
         pl_zip = ifelse(pl_zip == 0, df_zip, as.character(pl_zip)),
         X = as.character(X),
         Y = as.character(Y),
         appearance_time = as.character(appearance_time)) 

print(paste0("! Got master file"))

# Pull case comments
comments <- read_sheet(config$sheets$report, sheet = "Filings Last 4 Weeks") %>%
  janitor::clean_names(.) %>%
  select(case_number, rental_assistance_org:outcome_notes) %>%
  mutate(case_number = as.character(case_number)) %>%
  group_by(case_number) %>%
  summarise(
    across(
      everything(),
      ~ paste(unique(na.omit(.x)), collapse = " | "),
      .names = "{.col}"
    ),
    .groups = "drop"
  )

print(paste0("! Pulled comments from GS"))

## JOINING WITH MASTER ##

if (nrow(daily) > 0) {
  df <- daily %>% 
    select(-c("df_complete", "lat", "long", "arcgis_address", "score", "location.x", "location.y", "extent.xmin", "extent.ymin", "extent.xmax", "extent.ymax")) %>%
    select(-(attributes.Loc_name:attributes.StrucDet)) %>%
    full_join(master) %>%
  
  # More adjustments
  mutate(
    court = str_squish(ifelse(court == "Court 3-3", "Court 3-2", court)),
    appearance_time = case_when(
      str_detect(appearance_time, "^\\d{1,2}:\\d{2} [AP]M$") ~ format(strptime(appearance_time, "%I:%M %p"), "%H:%M:%S"),
      str_detect(appearance_time, "^\\d{1,2}:\\d{2}:\\d{2}$") ~ format(strptime(appearance_time, "%H:%M:%S"), "%H:%M:%S"),
      TRUE ~ NA_character_),
    appearance_time = str_replace(appearance_time, c("12/30/1899 |1899-12-31 "), "")
  ) %>%
  mutate_at(vars(plaintiff_name, 
                 pl_address, 
                 pl_city, 
                 defendant_name, 
                 df_address, 
                 df_city), 
            str_to_title) %>%
    
  # Add commentary (assistance orgs/notes)
  left_join(comments, by = "case_number", suffix = c("", ".upd")) %>%
  mutate(
    rental_assistance_org = ifelse(!is.na(rental_assistance_org.upd), rental_assistance_org.upd, rental_assistance_org),
    legal_assistance_org = ifelse(!is.na(legal_assistance_org.upd), legal_assistance_org.upd, legal_assistance_org),
    outcome_notes = ifelse(!is.na(outcome_notes.upd), outcome_notes.upd, outcome_notes)
  ) %>%
  select(-ends_with(".upd")) %>%
  
  # Reordering columns
  relocate(case_number, case_type, court, filed_date,
           appearance_date, appearance_time, non_payment_of_rent,
           plaintiff_name, pl_address, pl_city, pl_state, pl_zip, pl_phone, 
           defendant_name, df_address, df_addnum, df_city, df_state, df_zip, df_phone, 
           amount, amount_filed, monthly_rent, 
           attorney_fee, subsidy_tenant, subsidy_govt, 
           X, Y, case_number, rental_assistance_org, legal_assistance_org, outcome_notes) %>%
  
  # Removing duplicates
  distinct()

  print(paste0("! Joined new rows to master"))
} else {
  # If no daily files, just use the master data
  df <- master
  print(paste0("! No new daily files to process, using existing master data"))
}


### SUMMARIZE TIME AND DATE

docket <- df %>%
  filter(appearance_date >= today(), appearance_date < (today() + years(1))) %>%
  mutate(
    appearance_time = case_when(
      str_detect(appearance_time, "^\\d{1,2}:\\d{2}:\\d{2}$") ~ sprintf("%02d:%02d:00",
                                                                        ifelse(lubridate::hour(hms(appearance_time)) < 8, lubridate::hour(hms(appearance_time)) + 12, lubridate::hour(hms(appearance_time))),
                                                                        (lubridate::minute(hms(appearance_time)) %/% 30) * 30),
      TRUE ~ "Unassigned"
    )) %>%
  group_by(court, appearance_date, appearance_time) %>%
  summarize(cases = n(), .groups = 'drop') %>%
  arrange(court, appearance_time) %>%
  group_by(appearance_time) %>%
  ungroup() %>%
  pivot_wider(names_from = appearance_date, values_from = cases, values_fill = 0) %>%
  arrange(court, appearance_time) %>%
  mutate(court = ifelse(duplicated(court), NA_character_, court)) %>%
  janitor::adorn_totals("row")

print(paste0("! Created docket"))

# CHECK FOR BAD ENTRIES
# bad <- df %>%
#   mutate(across(everything(), as.character)) %>%
#   summarize(across(everything(), ~max(nchar(.x), na.rm = T)))
# 
# uhoh <- df %>%
#   filter(nchar(plaintiff_name) > 1000)


### WRITE TO GS

# Write recent eviction filings to GS
range_write(data = df %>%
              select(-X,-Y) %>%
              filter(filed_date >= (today() - lubridate::weeks(4))) %>%
              arrange(desc(filed_date)),
            ss = sheets$report,
            sheet = "Filings Last 4 Weeks",
            range = "A2:45000",
            col_names = FALSE)

print(paste0("! Wrote recent filings to GS"))

# Write older eviction filings to GS
range_write(data = df %>%
              select(-X,-Y) %>%
              filter(filed_date > (today() - lubridate::weeks(27)) & # half a year
                       (filed_date < (today() - lubridate::weeks(4)))) %>%
              arrange(desc(filed_date)),
            ss = sheets$report,
            sheet = "Archived Eviction Filings",
            range = "A2:45000",
            col_names = FALSE)

print(paste0("! Wrote archived filings to GS"))

# Write docket to GS
sheet_write(docket, 
            sheets$report,
            sheet = "Eviction Docket by Court")

print(paste0("! Wrote dockets to GS"))

### EXPORT BACK TO MASTER

# parquet (immune to strange characters)
write_parquet(df, project_file$master$daily$parquet)

# csv (easier to access)
export(df, project_file$master$daily$csv)

print(paste0("! Exported updated master"))


# Export geocoding errors
errors <- daily %>%
  filter(score < 98) %>%
  select(c("case_number", "df_address", "df_city", "df_state", "df_zip", "lat", "long"))


geocode_review <- import(reviewGeoFile) %>%
  select(c("case_number", "df_address", "df_city", "df_state", "df_zip", "lat", "long")) %>%
  mutate(
    df_zip = as.character(df_zip)
  ) %>%
  full_join(errors) %>%
  distinct()

export(geocode_review, reviewGeoFile)

print(paste0("! Exported geocoding errors"))

print("!! Success!")
