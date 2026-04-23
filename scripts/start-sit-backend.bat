@echo off
echo Starting Flow-Space Backend in SIT Environment...
echo.

REM Set environment to SIT
set NODE_ENV=sit

REM Navigate to backend directory
cd backend\node-backend

REM Check if .env.sit exists
if not exist ".env.sit" (
    echo ERROR: .env.sit file not found!
    echo Please create the .env.sit file with your database configuration.
    pause
    exit /b 1
)

echo Environment: SIT
echo Config File: .env.sit
echo Port: 8000
echo.

REM Start the server
echo Starting backend server...
npm start

pause
