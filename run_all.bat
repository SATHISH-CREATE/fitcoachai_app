@echo off
setlocal enabledelayedexpansion
title FitCoach AI - System Launcher

echo ===========================================
echo    FITCOACH AI - CONNECTIVITY ENGINE
echo ===========================================

:: 1. Auto-update IP in Mobile Config
echo 1. Syncing IP Address...
python update_ip.py

:: 2. Setup ADB Forwarding (for USB connection)
echo 2. Setting up USB Tunnel (ADB Reverse)...
where adb >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    adb reverse tcp:8086 tcp:8086
    echo    [OK] ADB reverse enabled for physical devices.
) else (
    :: Try hardcoded path if not in global path
    "C:\Users\sathi\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8086 tcp:8086 2>nul
    if !ERRORLEVEL! EQU 0 (
        echo    [OK] ADB reverse enabled via Sdk path.
    ) else (
        echo    [WARN] ADB not found. USB connection may require manual setup.
    )
)

:: 3. Start Backend
echo 3. Starting Backend Server...
start "FitCoach Backend" cmd /k "cd backend && venv\Scripts\activate && python main.py"

:: 4. Start Mobile (Optional Desktop Run)
echo 4. Starting Mobile App (Windows Desktop)...
echo    (Note: For Android, run 'flutter run' in the mobile folder)
start "FitCoach Mobile" cmd /k "cd mobile && flutter run -d windows"

echo.
echo ===========================================
echo    SYSTEMS ONLINE!
echo ===========================================
echo.
pause
