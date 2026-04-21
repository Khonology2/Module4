# 🚀 Quick Start - Backend Server

## Option 1: Start on Port 8000 (Recommended)

Run this in a **new terminal window**:

```powershell
cd backend
.\start-server.ps1
```

The server will start on `http://localhost:8000`

## Option 2: Start with default settings (Port 8000)

If the port script is unavailable, start the backend normally:

```powershell
cd backend
.\start-server.ps1
```

## Verify Server is Running

Open browser: `http://localhost:8000/health`

You should see a health check response.

## Troubleshooting

- **Database connection error**: Make sure PostgreSQL is running
- **Port already in use**: Kill the process using that port
- **Module not found**: Run `npm install` in the backend folder

