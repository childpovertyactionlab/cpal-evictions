# PowerShell script for Windows development
# This is the Windows equivalent of docker-dev.sh

param(
    [Parameter(Position=0)]
    [string]$Command = "",
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
Set-Location $ProjectRoot

function Show-Usage {
    Write-Host "CPAL Evictions Docker Development Helper (Windows)"
    Write-Host "=================================================="
    Write-Host ""
    Write-Host "Usage: .\docker-dev.ps1 [command] [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  dev          Start development environment (interactive shell)"
    Write-Host "  build        Build development image"
    Write-Host "  test         Run test suite"
    Write-Host "  script       Run a specific R script"
    Write-Host "  shell        Open shell in development container"
    Write-Host "  clean        Clean up containers and images"
    Write-Host "  logs         Show logs from running containers"
    Write-Host "  status       Show status of containers"
    Write-Host ""
    Write-Host "Data Sync Commands (mimics Jenkins pipeline):"
    Write-Host "  sync         Sync DCAD data from SFTP"
    Write-Host "  data-sync    Run complete data sync (SFTP + DCAD)"
    Write-Host "  process      Run R scripts with synced data"
    Write-Host "  pipeline     Run complete pipeline (SFTP + DCAD + R scripts)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\docker-dev.ps1 dev                    # Start development environment"
    Write-Host "  .\docker-dev.ps1 script data-review.R   # Run specific script"
    Write-Host "  .\docker-dev.ps1 test                   # Run all tests"
    Write-Host "  .\docker-dev.ps1 shell                  # Open interactive shell"
    Write-Host ""
    Write-Host "Data Pipeline Examples:"
    Write-Host "  .\docker-dev.ps1 data-sync              # Run complete data sync (SFTP + DCAD)"
    Write-Host "  .\docker-dev.ps1 sync                   # Sync DCAD data from SFTP (legacy)"
    Write-Host "  .\docker-dev.ps1 script <name>          # Run R scripts with data"
    Write-Host "  .\docker-dev.ps1 pipeline               # Run complete pipeline"
    Write-Host ""
}

function Build-Dev {
    Write-Host "Building development image..."
    docker-compose -f docker/docker-compose.yml build dev
}

function Start-Dev {
    Write-Host "Starting development environment..."
    docker-compose -f docker/docker-compose.yml up -d dev
    Write-Host "Development environment started. Use '.\docker-dev.ps1 shell' to access the container."
}

function Run-Script {
    param([string]$ScriptName)
    
    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        Write-Host "ERROR: Please specify a script to run"
        Write-Host "Available scripts:"
        docker-compose -f docker/docker-compose.yml run --rm analysis
        exit 1
    }
    
    Write-Host "Running script: $ScriptName"
    docker-compose -f docker/docker-compose.yml --profile data run --rm analysis $ScriptName
}

function Run-Tests {
    Write-Host "Running test suite..."
    docker-compose -f docker/docker-compose.test.yml up --abort-on-container-exit test-runner
}

function Open-Shell {
    Write-Host "Opening shell in development container..."
    docker-compose -f docker/docker-compose.yml exec dev bash
}

function Show-Logs {
    docker-compose -f docker/docker-compose.yml logs -f
}

function Show-Status {
    Write-Host "Container Status:"
    Write-Host "================="
    docker-compose -f docker/docker-compose.yml ps
}

function Clean-Up {
    Write-Host "Cleaning up containers and images..."
    docker-compose -f docker/docker-compose.yml down --rmi local --volumes --remove-orphans
    docker-compose -f docker/docker-compose.test.yml down --rmi local --volumes --remove-orphans
    Write-Host "Cleanup complete."
}

function Sync-DCAD {
    Write-Host "Syncing additional DCAD data from SFTP (legacy command)..."
    Write-Host "Note: This command is deprecated. Use 'data-sync' instead."
    docker-compose -f docker/docker-compose.yml --profile data up --abort-on-container-exit data-sync
    Write-Host "DCAD data synced successfully."
}

function Data-Sync {
    Write-Host "Running complete data sync (SFTP + DCAD)..."
    docker-compose -f docker/docker-compose.yml --profile data up --abort-on-container-exit data-sync
    Write-Host "Complete data sync finished."
}

function Process-Data {
    Write-Host "Running R scripts with synced data..."
    docker-compose -f docker/docker-compose.yml --profile data up --abort-on-container-exit analysis
    Write-Host "Data processing completed."
}

function Run-Pipeline {
    Write-Host "Running complete pipeline (SFTP + DCAD + R scripts)..."
    docker-compose -f docker/docker-compose.yml --profile data up --abort-on-container-exit
    Write-Host "Complete pipeline finished."
}

# Main command handling
switch ($Command.ToLower()) {
    "dev" {
        Build-Dev
        Start-Dev
    }
    "build" {
        Build-Dev
    }
    "test" {
        Run-Tests
    }
    "script" {
        Run-Script -ScriptName $Arguments[0]
    }
    "shell" {
        Open-Shell
    }
    "clean" {
        Clean-Up
    }
    "logs" {
        Show-Logs
    }
    "status" {
        Show-Status
    }
    "data-sync" {
        Data-Sync
    }
    "sync" {
        Sync-DCAD
    }
    "process" {
        Process-Data
    }
    "pipeline" {
        Run-Pipeline
    }
    { $_ -in "help", "-h", "--help", "" } {
        Show-Usage
    }
    default {
        Write-Host "ERROR: Unknown command '$Command'"
        Write-Host ""
        Show-Usage
        exit 1
    }
}

