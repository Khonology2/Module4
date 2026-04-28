# Database Configuration Restore Script
Write-Host "Restoring database configuration from backup..."

# Restore environment files
if (Test-Path "backups\db-config\db_config_backup_20260415_110228.env") {
    Copy-Item "backups\db-config\db_config_backup_20260415_110228.env" "backend\.env"
} else {
    Write-Host "Warning: Could not restore backend\.env" -ForegroundColor Yellow
}

if (Test-Path "backups\db-config\db_config_backup_20260415_110228.sit.env") {
    Copy-Item "backups\db-config\db_config_backup_20260415_110228.sit.env" "backend\node-backend\.env.sit"
} else {
    Write-Host "Warning: Could not restore .env.sit" -ForegroundColor Yellow
}

if (Test-Path "backups\db-config\db_config_backup_20260415_110228.dbPool.js") {
    Copy-Item "backups\db-config\db_config_backup_20260415_110228.dbPool.js" "backend\dbPool.js"
} else {
    Write-Host "Warning: Could not restore dbPool.js" -ForegroundColor Yellow
}

Write-Host "Database configuration restore completed!"
Write-Host "Please restart your backend services."
