@echo off
echo ========================================
echo    Flow-Space Backend Server Startup
echo ========================================
echo.

cd /d "%~dp0\backend\node-backend"

echo Starting server on http://localhost:8000...
echo.
echo Press Ctrl+C to stop the server
echo.

npm start

echo.
echo Server stopped.
pause
