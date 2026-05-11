# Start Flow-Space Backend in SIT Environment
Write-Host "Starting Flow-Space Backend in SIT Environment..." -ForegroundColor Green
Write-Host ""

# Set environment to SIT
$env:NODE_ENV = "sit"

# Navigate to backend directory
Set-Location "backend\node-backend"

# Check if .env.sit exists
if (-not (Test-Path ".env.sit")) {
    Write-Host "ERROR: .env.sit file not found!" -ForegroundColor Red
    Write-Host "Please create the .env.sit file with your database configuration."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Environment: SIT" -ForegroundColor Yellow
Write-Host "Config File: .env.sit" -ForegroundColor Yellow
Write-Host "Port: 8000" -ForegroundColor Yellow
Write-Host ""

# Start the server
Write-Host "Starting backend server..." -ForegroundColor Blue
npm start

Read-Host "Press Enter to exit"
