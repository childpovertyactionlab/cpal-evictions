# Simple test script to verify the R environment is working
# This script doesn't require any data files and won't send live data

cat("=== CPAL Evictions Environment Test ===\n")

# Test 1: Basic R functionality
cat("1. Testing basic R functionality...\n")
cat("   R version:", R.version.string, "\n")
cat("   Working directory:", getwd(), "\n")

# Test 2: Package loading
cat("2. Testing package loading...\n")
library(tidyverse)
library(sf)
library(config)
cat("   ✓ All packages loaded successfully\n")

# Test 3: Spatial libraries
cat("3. Testing spatial libraries...\n")
cat("   GEOS version:", sf_extSoftVersion()["GEOS"], "\n")
cat("   GDAL version:", sf_extSoftVersion()["GDAL"], "\n")
cat("   PROJ version:", sf_extSoftVersion()["PROJ"], "\n")

# Test 4: Configuration loading
cat("4. Testing configuration loading...\n")
config <- config::get()
cat("   ✓ Configuration loaded successfully\n")
cat("   Available config sections:", paste(names(config), collapse = ", "), "\n")

# Test 5: Data directory structure
cat("5. Testing data directory structure...\n")
if (dir.exists("data")) {
  cat("   ✓ Data directory exists\n")
  cat("   Data directory contents:\n")
  for (item in list.dirs("data", recursive = FALSE)) {
    cat("     -", basename(item), "\n")
  }
} else {
  cat("   ⚠ Data directory not found\n")
}

# Test 6: Scripts directory
cat("6. Testing scripts directory...\n")
if (dir.exists("scripts")) {
  cat("   ✓ Scripts directory exists\n")
  r_scripts <- list.files("scripts", pattern = "\\.R$", full.names = FALSE)
  cat("   Available R scripts:", length(r_scripts), "\n")
  for (script in head(r_scripts, 5)) {
    cat("     -", script, "\n")
  }
  if (length(r_scripts) > 5) {
    cat("     ... and", length(r_scripts) - 5, "more\n")
  }
} else {
  cat("   ⚠ Scripts directory not found\n")
}

# Test 7: Simple data manipulation
cat("7. Testing data manipulation...\n")
test_data <- data.frame(
  id = 1:5,
  name = c("Alice", "Bob", "Charlie", "Diana", "Eve"),
  value = runif(5, 1, 100)
)
cat("   ✓ Created test data frame\n")
cat("   Summary of test data:\n")
print(summary(test_data))

# Test 8: Simple spatial operations
cat("8. Testing spatial operations...\n")
# Create a simple point
point <- st_point(c(0, 0))
cat("   ✓ Created spatial point\n")

# Create a simple polygon
polygon <- st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE)))
cat("   ✓ Created spatial polygon\n")

cat("\n=== All Tests Completed Successfully! ===\n")
cat("The R environment is fully functional and ready for development.\n")
