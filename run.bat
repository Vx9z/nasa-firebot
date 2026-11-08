@echo off
setlocal
title NASA Fire in Freefall - dev

echo ============================================================
echo   NASA "Fire in Freefall" - one-command dev launcher
echo     1) FireBot backend (Flask + Gemini)  - 127.0.0.1:8000
echo     2) Flutter CRT app (hot reload)      - edge
echo ============================================================
echo.

cd /d "%~dp0"

netstat -ano | findstr ":8000" | findstr /c:"LISTENING" >nul 2>&1
if %errorlevel%==0 (
    echo [backend] already running on :8000 - reusing it.
) else (
    echo [backend] starting Flask in a new window...
    start "FireBot Backend (Flask)" /D "%~dp0ai\web" python app.py
)

echo [app] launching Flutter...
cd /d "%~dp0app"
flutter run -d edge

echo.
pause
endlocal
