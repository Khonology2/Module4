# 🚀 How to Start the App

## Step 1: Start Backend Server

Open a **new terminal/PowerShell window** and run:

```powershell
cd backend
.\start-server.ps1
```

Wait until you see: `🚀 Server running on port 8000`

## Step 2: Start Flutter App

In your **current terminal** (or a new one), run:

```powershell
flutter run -d chrome
```

The app will open in Chrome and connect to the backend automatically.

## ✅ Quick Check

- Backend running? → Open `http://localhost:8000/health` in browser
- App running? → Should open automatically in Chrome
- Connection error? → Make sure backend is running first!

## 🔧 All Services Updated

All Flutter services now use port **8000**:
- ✅ api_client.dart
- ✅ api_service.dart  
- ✅ document_service.dart
- ✅ notification_service.dart
- ✅ All other services

