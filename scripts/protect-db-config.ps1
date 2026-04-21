# Database Configuration Protection Script (PowerShell)
# This script checks for potential database configuration conflicts before git operations

Write-Host "Checking database configuration protection..."

# List of protected files
$protectedFiles = @(
    "backend\.env",
    "backend\.env.sit", 
    "backend\node-backend\.env.sit",
    "backend\dbPool.js"
)

# Get files that would be modified in the next merge/pull
$changedFiles = git diff --name-only HEAD@{1} HEAD 2>$null

if ($changedFiles) {
    foreach ($file in $protectedFiles) {
        if ($changedFiles -match [regex]::Escape($file)) {
            Write-Host "WARNING: Attempting to modify protected database configuration file: $file" -ForegroundColor Yellow
            Write-Host "This file contains your database credentials and connection settings."
            Write-Host ""
            Write-Host "Options:"
            Write-Host "1. Create a backup first: .\scripts\backup-db-config.ps1"
            Write-Host "2. Stash your changes before pulling"
            Write-Host "3. Review changes manually with git diff"
            Write-Host ""
            
            $continue = Read-Host "Do you want to continue anyway? (y/N)"
            if ($continue -notmatch '^[Yy]$') {
                Write-Host "Operation aborted to protect database configuration." -ForegroundColor Red
                exit 1
            }
        }
    }
}

Write-Host "Database configuration check passed. Proceeding with operation." -ForegroundColor Green
