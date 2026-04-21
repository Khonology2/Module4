@echo off
echo Running database migration to add missing project columns...
echo.

REM Check if psql is available
where psql >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: psql (PostgreSQL client) not found in PATH
    echo Please install PostgreSQL or add psql to your PATH
    echo.
    echo You can also run this manually using pgAdmin:
    echo 1. Open pgAdmin
    echo 2. Connect to your database
    echo 3. Open Query Tool
    echo 4. Copy and paste the contents of: backend\database\fix_project_end_dates.sql
    echo 5. Click Execute
    pause
    exit /b 1
)

echo PostgreSQL client found. Please enter your database credentials:
echo.

set /p username="Enter PostgreSQL username: "
set /p database="Enter database name: "
set /p host="Enter host (default: localhost): "

if "%host%"=="" set host=localhost

echo.
echo Running migration script...
echo.

psql -U %username% -d %database% -h %host% -f "backend\database\fix_project_end_dates.sql"

if %errorlevel% equ 0 (
    echo.
    echo ✅ SUCCESS: Database migration completed!
    echo.
    echo Please restart your backend server to pick up the changes.
    pause
) else (
    echo.
    echo ❌ ERROR: Migration failed. Please check the error messages above.
    echo.
    echo You can also try running the script manually in pgAdmin.
    pause
)
