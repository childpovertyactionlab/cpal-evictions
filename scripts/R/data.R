project_dir <- list(
  master = dpath('Dallas County Eviction Master')
)

project_file <- list(
  master = list(
    daily = file.path(project_dir$master, "EvictionRecords_Master"),
    weekly = file.path(project_dir$master, "EvictionRecords_WeeklyMaster")
  )
)

project_file$master$daily <- list(
  parquet = paste0(project_file$master$daily, ".parquet"),
  csv = paste0(project_file$master$daily, ".csv")
)

project_file$master$weekly = list(
  parquet = paste0(project_file$master$weekly, ".parquet"),
  csv = paste0(project_file$master$weekly, ".csv")
)
