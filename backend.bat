@echo off
title FireBot Backend (Flask)
cd /d "%~dp0ai\web"
echo FireBot backend (Flask + Gemini) - http://127.0.0.1:8000
echo Press Ctrl+C to stop.
echo.
python app.py
pause
