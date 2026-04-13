Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Flow-Space Backend Server Startup" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to the backend directory
$backendPath = Join-Path $PSScriptRoot "backend\node-backend"
Set-Location $backendPath

Write-Host "Starting server on http://localhost:3001..." -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Start the server
npm start

Write-Host ""
Write-Host "Server stopped." -ForegroundColor Red
Read-Host "Press Enter to continue"
