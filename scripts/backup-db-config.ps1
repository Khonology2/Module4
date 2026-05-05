# Database Configuration Backup Script (PowerShell)
# This script backs up your critical database configuration files

$BACKUP_DIR = "backups\db-config"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_NAME = "db_config_backup_$TIMESTAMP"

Write-Host "Creating database configuration backup..."

# Create backup directory
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

# Copy critical configuration files
if (Test-Path "backend\.env") {
    Copy-Item "backend\.env" "$BACKUP_DIR\$BACKUP_NAME.env"
} else {
    Write-Host "Warning: backend\.env not found" -ForegroundColor Yellow
}

if (Test-Path "backend\node-backend\.env.sit") {
    Copy-Item "backend\node-backend\.env.sit" "$BACKUP_DIR\$BACKUP_NAME.sit.env"
} else {
    Write-Host "Warning: .env.sit not found" -ForegroundColor Yellow
}

if (Test-Path "backend\dbPool.js") {
    Copy-Item "backend\dbPool.js" "$BACKUP_DIR\$BACKUP_NAME.dbPool.js"
} else {
    Write-Host "Warning: dbPool.js not found" -ForegroundColor Yellow
}

# Create a restore script
$restoreScript = @"
# Database Configuration Restore Script
Write-Host "Restoring database configuration from backup..."

# Restore environment files
if (Test-Path "$BACKUP_DIR\$BACKUP_NAME.env") {
    Copy-Item "$BACKUP_DIR\$BACKUP_NAME.env" "backend\.env"
} else {
    Write-Host "Warning: Could not restore backend\.env" -ForegroundColor Yellow
}

if (Test-Path "$BACKUP_DIR\$BACKUP_NAME.sit.env") {
    Copy-Item "$BACKUP_DIR\$BACKUP_NAME.sit.env" "backend\node-backend\.env.sit"
} else {
    Write-Host "Warning: Could not restore .env.sit" -ForegroundColor Yellow
}

if (Test-Path "$BACKUP_DIR\$BACKUP_NAME.dbPool.js") {
    Copy-Item "$BACKUP_DIR\$BACKUP_NAME.dbPool.js" "backend\dbPool.js"
} else {
    Write-Host "Warning: Could not restore dbPool.js" -ForegroundColor Yellow
}

Write-Host "Database configuration restore completed!"
Write-Host "Please restart your backend services."
"@

$restoreScript | Out-File -FilePath "$BACKUP_DIR\restore_$BACKUP_NAME.ps1" -Encoding UTF8

Write-Host "Backup completed: $BACKUP_DIR\"
Write-Host "To restore, run: .\$BACKUP_DIR\restore_$BACKUP_NAME.ps1"
