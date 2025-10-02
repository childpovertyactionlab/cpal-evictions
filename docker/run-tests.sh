#!/bin/bash

# Test runner script for cpal-evictions
# This script runs various tests to ensure the environment is working correctly

set -e

echo "=========================================="
echo "CPAL Evictions Test Suite"
echo "=========================================="

# Test 1: Check if R is available and working
echo "Test 1: R Environment Check"
echo "---------------------------"
R --version
Rscript -e "cat('R is working correctly\n')"

# Test 2: Check if required R packages are available
echo -e "\nTest 2: R Package Check"
echo "------------------------"
Rscript -e "
required_packages <- c('renv', 'config', 'stringr', 'dplyr')
missing_packages <- c()
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}
if (length(missing_packages) > 0) {
  cat('Missing packages:', paste(missing_packages, collapse = ', '), '\n')
  quit(status = 1)
} else {
  cat('All required packages are available\n')
}
"

# Test 3: Check if configuration loads correctly
echo -e "\nTest 3: Configuration Check"
echo "----------------------------"
if [ -f "config.yml" ]; then
    echo "Configuration file exists"
    Rscript -e "
    Sys.setenv(R_CONFIG_FILE = 'config.yml')
    if (requireNamespace('config', quietly = TRUE)) {
      tryCatch({
        config <- config::get()
        cat('Configuration loaded successfully\n')
      }, error = function(e) {
        cat('Configuration load failed:', e\$message, '\n')
        quit(status = 1)
      })
    } else {
      cat('config package not available\n')
      quit(status = 1)
    }
    "
else
    echo "ERROR: config.yml not found"
    exit 1
fi

# Test 4: Check if scripts directory exists and has R files
echo -e "\nTest 4: Scripts Directory Check"
echo "--------------------------------"
if [ -d "scripts" ]; then
    script_count=$(find scripts -name "*.R" | wc -l)
    echo "Found $script_count R scripts in scripts directory"
    if [ $script_count -gt 0 ]; then
        echo "Available scripts:"
        find scripts -name "*.R" -not -name "init.R" | sed 's/^/  - /'
    else
        echo "ERROR: No R scripts found in scripts directory"
        exit 1
    fi
else
    echo "ERROR: scripts directory not found"
    exit 1
fi

# Test 5: Check if entrypoint script is executable
echo -e "\nTest 5: Entrypoint Check"
echo "------------------------"
if [ -f "entrypoint.sh" ]; then
    if [ -x "entrypoint.sh" ]; then
        echo "Entrypoint script is executable"
        echo "Testing entrypoint (should show available scripts):"
        ./entrypoint.sh | head -10
    else
        echo "ERROR: entrypoint.sh is not executable"
        exit 1
    fi
else
    echo "ERROR: entrypoint.sh not found"
    exit 1
fi

# Test 6: Check data directory structure
echo -e "\nTest 6: Data Directory Check"
echo "-----------------------------"
if [ -d "data" ]; then
    echo "Data directory exists"
    echo "Data directory contents:"
    ls -la data/ | head -10
else
    echo "WARNING: data directory not found (this may be expected for fresh setup)"
fi

# Test 7: Test renv functionality
echo -e "\nTest 7: renv Check"
echo "------------------"
if [ -f "renv.lock" ]; then
    echo "renv.lock file exists"
    Rscript -e "
    if (requireNamespace('renv', quietly = TRUE)) {
      cat('renv package is available\n')
      # Check if we can read the lock file
      tryCatch({
        lockfile <- renv::lockfile_read('renv.lock')
        cat('renv.lock file is readable\n')
      }, error = function(e) {
        cat('ERROR: Cannot read renv.lock:', e\$message, '\n')
        quit(status = 1)
      })
    } else {
      cat('ERROR: renv package not available\n')
      quit(status = 1)
    }
    "
else
    echo "WARNING: renv.lock not found"
fi

echo -e "\n=========================================="
echo "All tests completed successfully!"
echo "=========================================="
