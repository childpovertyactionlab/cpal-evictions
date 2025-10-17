library(tidyverse)
library(lubridate)
# this script is to generate empty excel sheets to place in the daily archive for 8.28-9.16.
# those dates are covered in the master dataset


# Path to your master CSV
master_file <- readxl::read_xls('/Users/anushachowdhury/Downloads/evictions/Dallas County Daily Eviction Reports/archive/Eviction_Data_Daily_0513.xls')

# Read just the header
master_cols <- names(master_file)

# Create empty names()# Create empty data frame with same columns
empty_df <- as.data.frame(matrix(ncol = length(master_cols), nrow = 0))
colnames(empty_df) <- master_cols

# Define date range
dates <- seq(as.Date("2024-08-27"), as.Date("2024-09-16"), by = "day")

mmdd <- paste0(0, month(dates), ifelse(day(dates) < 10, 0, ""), day(dates))

out_dir <- "data/filling missing days"
for (d in mmdd) {
  file_name <- paste0("Eviction_Data_Daily_", d, ".xls")
  out_path <- file.path(out_dir, file_name)
  
  writexl::write_xlsx(empty_df, out_path)
}

readxl::read_xlsx('data/filling missing days/Eviction_Data_Daily_0827.xls')
