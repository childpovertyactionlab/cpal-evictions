# Docker Development Environment for CPAL Evictions

This folder contains all Docker-related files for the CPAL Evictions project development and testing environment. This comprehensive guide covers everything you need to know about using Docker for development and testing.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [RStudio Integration](#rstudio-integration)
5. [File Structure](#file-structure)
6. [Services](#services)
7. [Usage Examples](#usage-examples)
8. [Configuration](#configuration)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)

## Overview

The Docker Compose setup provides:
- **Development environment** with live code synchronization
- **Testing environment** with automated test suites
- **Ubuntu-based containers** using the tumblR base image
- **Interactive development** with shell access
- **Script execution** for R analysis scripts
- **RStudio IDE integration** for familiar development experience

## Prerequisites

- Docker and Docker Compose installed
- Access to the tumblR base image: `tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609` (hosted on AWS ECR)
- Git repository cloned locally
- RStudio IDE installed locally (for integration)

## Quick Start

### 1. Start Development Environment

```bash
# Using the helper script (recommended)
./docker-dev.sh dev

# Or using docker-compose directly
docker-compose -f docker/docker-compose.yml up -d dev
```

### 2. Access the Development Container

#### Option A: RStudio IDE Integration (Recommended for Interactive Development)

Use your local RStudio IDE with Docker integration for the best development experience:

```bash
# Start the development environment
./docker-dev.sh dev

# Then configure RStudio to use the Docker container
# See RStudio Integration section below for detailed setup
```

**Benefits:**
- Use familiar RStudio GUI
- Live code synchronization
- Same environment as production
- No server overhead

#### Option B: Command Line Shell

```bash
# Open an interactive shell
./docker-dev.sh shell

# Or directly
docker-compose -f docker/docker-compose.yml exec dev bash
```

### 3. Run Tests

```bash
# Run the full test suite
./docker-dev.sh test

# Or using docker-compose
docker-compose -f docker/docker-compose.test.yml up --abort-on-container-exit test-runner
```

## RStudio Integration

This section shows how to use your local RStudio IDE with the Docker development environment.

### Overview

With this setup, developers can:
- Use their familiar RStudio GUI locally
- Run R code inside the Docker container
- Have live code synchronization with Docker Compose
- Maintain the same environment as production

### Setup Instructions

#### 1. Start the Development Environment

```bash
# Start the development container
./docker-dev.sh dev

# Verify it's running
./docker-dev.sh status
```

#### 2. Configure RStudio for Docker Integration

##### Option A: Using RStudio's Built-in Docker Support (Recommended)

1. **Open RStudio IDE**
2. **Go to Tools → Global Options → General**
3. **Click on "Change..." next to "R version"**
4. **Select "Docker" as the R version source**
5. **Configure the Docker connection:**
   - **Image**: `docker-dev:latest` (or the name of your built image)
   - **Container**: `cpal-evictions-dev`
   - **Working Directory**: `/app`

##### Option B: Using RStudio's Terminal Integration

1. **Open RStudio IDE**
2. **Go to Tools → Terminal → New Terminal**
3. **In the terminal, run:**
   ```bash
   # Access the Docker container
   ./docker-dev.sh shell
   
   # Now you're inside the container
   # You can run R commands directly
   R
   ```

### Working with Files

#### Live Code Synchronization

The Docker Compose setup includes file watching, so:
- **Edit files in your local RStudio**
- **Changes are automatically synced to the container**
- **Run code in the container environment**

#### File Locations

- **Local RStudio**: Edit files in your project directory
- **Container**: Files are mounted at `/app/`
- **Scripts**: Available at `/app/scripts/`
- **Data**: Available at `/app/data/`

### Running R Scripts

#### From RStudio Terminal

```bash
# Access container shell
./docker-dev.sh shell

# Run R scripts
Rscript scripts/data-review.R
Rscript scripts/eviction-records-ntep-join-and-clean.R
```

#### From RStudio R Console

```r
# Set working directory to match container
setwd("/path/to/your/project")

# Source the environment setup
source("scripts/R/environment.R")

# Run your analysis
source("scripts/data-review.R")
```

### Package Management

The container uses `renv` for package management:

```r
# In RStudio R Console
# Install new packages (they'll be added to renv.lock)
install.packages("new_package")

# Update renv.lock
renv::snapshot()

# Restore packages in container
renv::restore()
```

### Development Workflow

#### Typical Workflow

1. **Start development environment:**
   ```bash
   ./docker-dev.sh dev
   ```

2. **Open RStudio IDE**

3. **Edit R scripts in RStudio**

4. **Test scripts in container:**
   ```bash
   ./docker-dev.sh script your-script.R
   ```

5. **Run tests:**
   ```bash
   ./docker-dev.sh test
   ```

#### File Synchronization

- **Local changes** → **Container** (automatic via Docker Compose volumes)
- **Container changes** → **Local** (automatic via Docker Compose volumes)
- **No manual copying needed**

## File Structure

This folder contains:

- **`Dockerfile.dev`** - Development Docker image that extends the tumblR base image
- **`docker-compose.yml`** - Main development environment with multiple services
- **`docker-compose.test.yml`** - Testing environment with automated test suites
- **`docker-dev.sh`** - Helper script for common development tasks
- **`run-tests.sh`** - Comprehensive test runner script
- **`example-usage.sh`** - Example workflow demonstration
- **`README.md`** - This comprehensive documentation

## Services

### Development Services

#### `dev` - Interactive Development
- **Purpose**: Interactive development with live code synchronization
- **Access**: Shell access, file watching, persistent volumes
- **Command**: `./docker-dev.sh dev`

#### `analysis` - Script Execution
- **Purpose**: Run specific R analysis scripts
- **Access**: One-time script execution
- **Command**: `./docker-dev.sh script <script-name>`

#### `data-processing` - Data Processing
- **Purpose**: Run data processing tasks
- **Access**: Automated data processing workflows
- **Command**: `./docker-dev.sh script data-processing.R`

### Testing Services

#### `test-runner` - Test Execution
- **Purpose**: Run automated test suites
- **Access**: Comprehensive testing environment
- **Command**: `./docker-dev.sh test`

#### `test-data-setup` - Test Data Preparation
- **Purpose**: Set up test data and environments
- **Access**: Automated test data preparation
- **Command**: Part of test suite

## Usage Examples

### Basic Development Workflow

```bash
# 1. Start development environment
./docker-dev.sh dev

# 2. Access container shell
./docker-dev.sh shell

# 3. Run a specific script
./docker-dev.sh script data-review.R

# 4. Run tests
./docker-dev.sh test

# 5. Check container status
./docker-dev.sh status

# 6. View logs
./docker-dev.sh logs

# 7. Clean up when done
./docker-dev.sh clean
```

### Running Specific R Scripts

```bash
# List available scripts
./docker-dev.sh script

# Run a specific script
./docker-dev.sh script eviction-records-ntep-join-and-clean.R

# Run with custom arguments
docker-compose -f docker/docker-compose.yml run --rm analysis your-script.R
```

### Testing Workflow

```bash
# Run full test suite
./docker-dev.sh test

# Run specific test
docker-compose -f docker/docker-compose.test.yml run --rm test-runner

# Check test results
./docker-dev.sh logs
```

## Configuration

### Environment Variables

The following environment variables are available:

- **`ENV`**: Environment type (`development`, `test`, `production`)
- **`R_CONFIG_FILE`**: Path to configuration file (`/app/config.yml`)
- **`TZ`**: Timezone (`America/Chicago`)

### Volume Mounts

The following directories are mounted:

- **`../scripts:/app/scripts`** - R scripts for live editing
- **`../data:/app/data`** - Data directory for persistent storage
- **`../config.yml:/app/config.yml`** - Configuration file
- **`../renv.lock:/app/renv.lock`** - Package lock file
- **`../renv:/app/renv`** - Package cache
- **`../DESCRIPTION:/app/DESCRIPTION`** - R package description

### Build Context

All Docker Compose files are configured to build from the project root directory (`context: ..`) while keeping the Docker files organized in this folder. This allows:

- Access to all project files (scripts, data, config, etc.)
- Clean organization of Docker-related files
- Easy maintenance and updates

## Testing

### Test Structure

The testing environment includes:

- **R Environment Tests**: Verify R version and package loading
- **Spatial Library Tests**: Test GEOS, GDAL, PROJ functionality
- **Configuration Tests**: Verify config file loading
- **Script Discovery Tests**: Test entrypoint script functionality
- **Data Directory Tests**: Verify data directory setup

### Running Tests

```bash
# Run all tests
./docker-dev.sh test

# Run specific test service
docker-compose -f docker/docker-compose.test.yml up test-runner

# Check test logs
docker-compose -f docker/docker-compose.test.yml logs test-runner
```

### Test Results

Tests verify:
- ✅ **R Environment**: R 4.4.1 with all required packages
- ✅ **Spatial Libraries**: GEOS 3.10.2, GDAL 3.4.1, PROJ 8.2.1
- ✅ **Configuration**: Config file loading and parsing
- ✅ **Script Discovery**: Entrypoint script and R script discovery
- ✅ **Package Management**: renv package restoration

## Troubleshooting

### Common Issues

#### Container Not Running

```bash
# Check status
./docker-dev.sh status

# Restart if needed
./docker-dev.sh dev

# Check logs
./docker-dev.sh logs
```

#### RStudio Can't Connect to Container

1. **Verify container is running:**
   ```bash
   docker ps | grep cpal-evictions
   ```

2. **Check container logs:**
   ```bash
   ./docker-dev.sh logs
   ```

3. **Restart container:**
   ```bash
   ./docker-dev.sh dev
   ```

#### Package Issues

```bash
# Rebuild container with updated packages
./docker-dev.sh build
./docker-dev.sh dev
```

#### Base Image Issues

If you encounter issues with the tumblR base image:

1. **Authenticate with AWS ECR:**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 678154373696.dkr.ecr.us-east-1.amazonaws.com
   ```

2. **Pull the base image:**
   ```bash
   docker pull 678154373696.dkr.ecr.us-east-1.amazonaws.com/tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609
   ```

3. **Tag it for local use:**
   ```bash
   docker tag 678154373696.dkr.ecr.us-east-1.amazonaws.com/tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609 tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609
   ```

#### Platform Warnings

If you see platform warnings (linux/amd64 vs linux/arm64), this is normal when building AMD64 images on ARM64 Macs. The warnings are harmless and the images will work correctly for Linux deployment.

### Getting Help

1. **Check container status**: `./docker-dev.sh status`
2. **View logs**: `./docker-dev.sh logs`
3. **Restart environment**: `./docker-dev.sh clean && ./docker-dev.sh dev`
4. **Verify base image**: `docker images | grep tumblr`

## Benefits of This Setup

✅ **Familiar Interface**: Use RStudio GUI you're already comfortable with
✅ **Consistent Environment**: Same R version and packages as production
✅ **Live Synchronization**: Changes sync automatically between local and container
✅ **Easy Testing**: Run scripts in container environment
✅ **Package Management**: Use renv for reproducible package management
✅ **No Server Overhead**: No need to run RStudio Server in container
✅ **Clean Organization**: All Docker files in one folder
✅ **Easy Maintenance**: Single comprehensive documentation

## Next Steps

1. **Start the development environment**: `./docker-dev.sh dev`
2. **Configure RStudio for Docker integration** (see RStudio Integration section)
3. **Begin development with live synchronization**
4. **Use the testing environment for validation**

The convenience script `docker-dev.sh` in the project root delegates to the actual scripts in this folder, so you can run commands from anywhere in the project.