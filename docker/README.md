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
- **SFTP data sync** for accessing production data without local storage
- **Jenkins pipeline replication** for local development

## Prerequisites

- Docker and Docker Compose installed
- Access to the tumblR base image: `tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609` (hosted on AWS ECR)
- Git repository cloned locally
- SSH key for SFTP access (see [Credentials Setup](#credentials-setup))
- RStudio IDE installed locally (for integration)

## Credentials Setup

Before using the development environment, you need to set up the required credentials:

### SFTP Access Setup

1. **Copy the SSH key file:**
   ```bash
   # Copy from your local credentials directory
   cp /path/to/your/credentials/SFTP_keys/evictions/evictionsuser docker/credentials/sftp/evictionsuser
   ```

2. **Set proper permissions:**
   ```bash
   chmod 600 docker/credentials/sftp/evictionsuser
   ```

3. **Verify the file exists:**
   ```bash
   ls -la docker/credentials/sftp/evictionsuser
   ```

For more detailed instructions, see [credentials/README.md](credentials/README.md).

## Windows Setup

This project provides both bash and PowerShell scripts for cross-platform compatibility.

### Option 1: PowerShell (Recommended for Windows)

Use the PowerShell script for native Windows support:

```powershell
.\docker-dev.ps1 data-sync
.\docker-dev.ps1 dev
.\docker-dev.ps1 script your-script.R
```

### Option 2: Bash (Git Bash or WSL2)

Use the bash script if you have WSL2 or Git Bash:

```bash
./docker-dev.sh data-sync
./docker-dev.sh dev
```

**Note**: The `.gitattributes` file ensures bash scripts use correct line endings. If you cloned before this was added, you may need to pull the latest changes and reset line endings:

```bash
git pull
git rm --cached -r .
git reset --hard
```

## Quick Start

### 1. Sync Data from SFTP and DCAD

```bash
# Mac/Linux/WSL
./docker-dev.sh data-sync

# Windows PowerShell
.\docker-dev.ps1 data-sync
```

### 2. Start Development Environment

```bash
# Mac/Linux/WSL
./docker-dev.sh dev

# Windows PowerShell
.\docker-dev.ps1 dev

# Or using docker-compose directly (any platform)
docker-compose -f docker/docker-compose.yml up -d dev
```

### 3. Access the Development Container

#### Option A: RStudio IDE Integration (Recommended for Interactive Development)

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

#### Option B: Direct Container Access

```bash
# Access container shell
./docker-dev.sh shell

# Run a specific script
./docker-dev.sh script eviction-records-daily-googlesheet-processing.R

# Run tests
./docker-dev.sh test
```

#### File Synchronization

- **Local changes** → **Container** (automatic via Docker Compose volumes)
- **Container changes** → **Local** (automatic via Docker Compose volumes)
- **No manual copying needed**

## File Structure

This folder contains:

- **`Dockerfile.dev`** - Development Docker image that extends the tumblR base image
- **`docker-compose.yml`** - Main development environment with SFTP data sync
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
- **Access**: One-time script execution with SFTP data access
- **Command**: `./docker-dev.sh script <script-name>`

### Testing Services

#### `test-runner` - Test Execution
- **Purpose**: Run automated test suites with SFTP data access
- **Access**: Comprehensive testing environment
- **Command**: `./docker-dev.sh test`

### Data Pipeline Services

#### `data-sync` - Combined Data Sync (SFTP + DCAD)
- **Purpose**: Sync data from both AWS SFTP server and DCAD SFTP server
- **Access**: Downloads all data from `/evictions` folder and fresh DCAD data
- **Command**: `./docker-dev.sh data-sync`
- **Mimics**: Jenkins "Connect to Data" + "Synchronize with DCAD" stages
- **Data Includes**:
  - Dallas County Eviction Master/ (with EvictionRecords_Master.parquet)
  - Dallas County Daily Eviction Reports/ (with all archived files)
  - Dallas County Weekly Eviction Reports/ (with all archived files)
  - bubble/ folder (with updated geojson files)
  - demo/ folder (with updated geojson files)
  - filing data/ folder (with updated CSV files)
  - geographies/ folder (with updated boundary files)
  - dcad-sync/ folder (with latest daily/weekly eviction files)
  - All other files and folders from /evictions

#### `sync` - Legacy DCAD Sync (Deprecated)
- **Purpose**: Legacy command for DCAD data sync only
- **Access**: Downloads fresh eviction data from DCAD
- **Command**: `./docker-dev.sh sync` (redirects to data-sync)
- **Note**: Use `data-sync` instead for complete data synchronization

#### `analysis` - R Script Processing
- **Purpose**: Process eviction data with R scripts
- **Access**: Runs R analysis scripts on synced data
- **Command**: `./docker-dev.sh script <script-name>`
- **Mimics**: Jenkins "Process New Evictions" stage

## Usage Examples

### Basic Development Workflow

```bash
# 1. Sync data from SFTP and DCAD (one-time setup)
./docker-dev.sh data-sync

# 2. Start development environment
./docker-dev.sh dev

# 3. Access container shell
./docker-dev.sh shell

# 4. Run a specific script
./docker-dev.sh script data-review.R

# 5. Run tests
./docker-dev.sh test

# 6. Check container status
./docker-dev.sh status

# 7. View logs
./docker-dev.sh logs

# 8. Clean up when done
./docker-dev.sh clean
```

### Running Specific R Scripts

```bash
# List available scripts
./docker-dev.sh script

# Run a specific script
./docker-dev.sh script eviction-records-daily-googlesheet-processing.R

# Run with custom arguments
docker-compose -f docker/docker-compose.yml --profile data run --rm analysis your-script.R
```

### Testing Workflow

```bash
# Run full test suite
./docker-dev.sh test

# Run specific test
docker-compose -f docker/docker-compose.test.yml --profile data run --rm test-runner

# Check test results
./docker-dev.sh logs
```

### Data Pipeline Workflow (Mimics Jenkins Pipeline)

The data pipeline workflow exactly replicates the Jenkins pipeline for local development:

#### Step 1: Complete Data Sync (SFTP + DCAD)
```bash
# Sync data from both AWS SFTP server and DCAD SFTP server
./docker-dev.sh data-sync

# This mimics Jenkins "Connect to Data" + "Synchronize with DCAD" stages
# Downloads ALL files from /evictions folder on AWS SFTP to local /data
# Downloads fresh daily/weekly eviction files from DCAD
# Data is cached locally for faster access
```

#### Step 2: Process Data with R Scripts
```bash
# Run R scripts to process the synced data
./docker-dev.sh script eviction-records-daily-googlesheet-processing.R

# This mimics Jenkins "Process New Evictions" stage
# Processes eviction data and updates Google Sheets
```

#### Complete Pipeline (All Steps)
```bash
# Run the complete pipeline in one command
./docker-dev.sh pipeline

# This runs: SFTP sync + DCAD sync → R processing
# Equivalent to running all Jenkins stages sequentially
```

#### Legacy Individual Steps (Deprecated)
```bash
# Legacy: Run SFTP sync only (deprecated)
./docker-dev.sh sftp-mount

# Legacy: Run DCAD sync only (deprecated)
./docker-dev.sh sync

# Note: Use 'data-sync' instead for complete data synchronization
```

#### Data Pipeline Order of Operations

1. **Combined Data Sync** (`data-sync`)
   - Connects to AWS SFTP server
   - Downloads all historical data from `/evictions` folder
   - Connects to DCAD SFTP server
   - Downloads fresh daily/weekly eviction files
   - Caches all data locally for faster access

2. **R Script Processing** (`script`)
   - Runs R analysis scripts on synced data
   - Processes eviction data
   - Updates Google Sheets

### Advanced Usage

#### Custom Docker Compose Commands

```bash
# Run specific service
docker-compose -f docker/docker-compose.yml --profile data up data-sync

# Run with specific profile
docker-compose -f docker/docker-compose.yml --profile data up

# Run in background
docker-compose -f docker/docker-compose.yml up -d

# View logs
docker-compose -f docker/docker-compose.yml logs -f

# Stop all services
docker-compose -f docker/docker-compose.yml down
```

#### Environment Variables

The following environment variables are available:

- `ENV`: Environment mode (development, test, production)
- `R_CONFIG_FILE`: Path to R configuration file
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to Google service account credentials
- `TZ`: Timezone setting

#### Volume Mounts

- `../scripts:/app/scripts` - R scripts directory
- `../data:/app/data` - Data directory (app access)
- `../data:/data` - Data directory (R script access)
- `../config.yml:/app/config.yml` - Configuration file
- `../.gsuite-service.json:/var/run/secrets/google` - Google credentials
- `../data/dcad-sync:/dcad-sync` - DCAD sync directory

## Configuration

### Google Service Account Setup

1. **Place credentials file:**
   ```bash
   # Copy your Google service account JSON file
   cp /path/to/your/gsuite-service.json .gsuite-service.json
   ```

2. **Verify file is mounted:**
   ```bash
   ./docker-dev.sh shell
   ls -la /var/run/secrets/google
   ```

### SFTP Access Setup

1. **Verify SSH key exists:**
   ```bash
   ls -la /Users/drew/Documents/CPAL/creds/SFTP_keys/evictions/evictionsuser
   ```

2. **Test SFTP connection:**
   ```bash
   ./docker-dev.sh sftp-mount
   ```

### Data Directory Structure

After running `sftp-mount`, your local `data/` directory will contain:

```
data/
├── Dallas County Eviction Master/
│   ├── EvictionRecords_Master.parquet
│   ├── EvictionRecords_Master.csv
│   └── ...
├── Dallas County Daily Eviction Reports/
│   ├── archive/
│   └── ...
├── Dallas County Weekly Eviction Reports/
│   ├── archive/
│   └── ...
├── bubble/
├── demo/
├── filing data/
├── geographies/
├── dcad-sync/
└── NTEP_eviction_cases.csv
```

## Testing

### Running Tests

```bash
# Run full test suite
./docker-dev.sh test

# Run specific test
docker-compose -f docker/docker-compose.test.yml --profile sftp run --rm test-runner

# Check test results
./docker-dev.sh logs
```

### Test Coverage

The test suite includes:
- R environment validation
- Package loading verification
- Configuration file testing
- Data access validation
- SFTP connection testing

## Troubleshooting

### Common Issues

#### 0. Windows: Script Errors or "Command does not exist"

**Problem**: Errors running bash scripts on Windows.

**Solution**: Use the PowerShell script instead:

```powershell
.\docker-dev.ps1 data-sync
```

Or if using Git Bash/WSL2, ensure you have the latest line endings:

```bash
git pull
git rm --cached -r .
git reset --hard
./docker-dev.sh data-sync
```

#### 1. Data Sync Failed
```bash
# Check SSH key exists and has proper permissions
ls -la docker/credentials/sftp/evictionsuser

# Fix permissions if needed
chmod 600 docker/credentials/sftp/evictionsuser

# Test data sync manually
./docker-dev.sh data-sync
```

#### 2. Data Not Found
```bash
# Verify data sync completed
./docker-dev.sh data-sync

# Check data directory
ls -la data/
```

#### 3. R Script Errors
```bash
# Check container logs
./docker-dev.sh logs

# Access container shell for debugging
./docker-dev.sh shell
```

#### 4. Google Sheets Authentication Failed
```bash
# Verify credentials file
ls -la .gsuite-service.json

# Check file is mounted in container
./docker-dev.sh shell
ls -la /var/run/secrets/google
```

### Debugging Commands

```bash
# View container status
./docker-dev.sh status

# View logs
./docker-dev.sh logs

# Access container shell
./docker-dev.sh shell

# Clean up and restart
./docker-dev.sh clean
./docker-dev.sh dev
```

### Performance Optimization

#### Data Sync Optimization
- Data is cached locally after first sync
- Subsequent syncs only download new/changed files
- Use `./docker-dev.sh sftp-mount` to refresh data

#### Container Performance
- Use `./docker-dev.sh dev` for interactive development
- Use `./docker-dev.sh script` for one-time script execution
- Clean up unused containers with `./docker-dev.sh clean`

## Best Practices

### Development Workflow
1. **Always sync data first**: `./docker-dev.sh data-sync`
2. **Use RStudio integration** for interactive development
3. **Test scripts frequently**: `./docker-dev.sh script your-script.R`
4. **Run tests before committing**: `./docker-dev.sh test`
5. **Clean up when done**: `./docker-dev.sh clean`

### Data Management
- **Don't commit data files** (they're in `.gitignore`)
- **Use data-sync** for fresh data from both SFTP and DCAD
- **Cache data locally** for faster access
- **Verify data integrity** before processing

### Container Management
- **Use helper scripts** instead of raw docker-compose commands
- **Monitor container status** with `./docker-dev.sh status`
- **Clean up regularly** to free disk space
- **Use profiles** for specific workflows

## Support

For issues or questions:
1. Check this README for common solutions
2. Review container logs: `./docker-dev.sh logs`
3. Check Docker status: `./docker-dev.sh status`
4. Clean and restart: `./docker-dev.sh clean && ./docker-dev.sh dev`