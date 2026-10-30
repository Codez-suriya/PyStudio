@echo off
setlocal enabledelayedexpansion
title PyStudio Launcher

:: 1. Check if Python and the virtual environment exist
if not exist "%~dp0.venv\Scripts\python.exe" (
    echo.
    echo [ERROR] Virtual environment missing.
    echo Please run the installer first.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0app.py" (
    echo.
    echo [ERROR] app.py not found in this folder.
    echo Please run the installer first.
    echo.
    pause
    exit /b 1
)

:: 2. Ask for the Port
echo.
echo  ========================================
echo    PyStudio Launcher
echo  ========================================
echo.
set "PORT=8000"
set /p "INPUT_PORT=  Port [default 8000]: "
if not "%INPUT_PORT%"=="" set "PORT=%INPUT_PORT%"

:: 3. Ask for Exposure Mode
echo.
echo  How should PyStudio be exposed?
echo    1) Have Domain      (bind 0.0.0.0, enter domain name)
echo    2) Expose Locally   (bind 127.0.0.1, this machine only)
echo    3) Expose to LAN    (bind detected LAN IP) [Default]
echo.
set "MODE=3"
set /p "INPUT_MODE=  Select [1/2/3, default 3]: "
if not "%INPUT_MODE%"=="" set "MODE=%INPUT_MODE%"

:: 4. Get Local IP for LAN mode
set "LAN_IP=127.0.0.1"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "LAN_IP=%%a"
    set "LAN_IP=!LAN_IP: =!"
    goto :ip_found
)
:ip_found

:: 5. Determine Host and URL
if "%MODE%"=="1" (
    set "BIND_HOST=0.0.0.0"
    set /p "DOMAIN_NAME=  Enter domain name (e.g. myapp.local): "
    if "!DOMAIN_NAME!"=="" (
        echo [WARN] No domain entered. Falling back to LAN.
        set "MODE=3"
        set "BIND_HOST=!LAN_IP!"
        set "DISPLAY_URL=http://!LAN_IP!:%PORT%"
    ) else (
        set "DISPLAY_URL=http://!DOMAIN_NAME!:%PORT%"
    )
) else if "%MODE%"=="2" (
    set "BIND_HOST=127.0.0.1"
    set "DISPLAY_URL=http://127.0.0.1:%PORT%"
) else (
    set "MODE=3"
    set "BIND_HOST=!LAN_IP!"
    set "DISPLAY_URL=http://!LAN_IP!:%PORT%"
)

:: 6. Print Summary
echo.
echo  [*] Starting PyStudio from %~dp0
echo  [*] Mode      : %MODE%
echo  [*] Bind host : %BIND_HOST%
echo  [*] Port      : %PORT%
echo  [*] URL       : %DISPLAY_URL%
if "%MODE%"=="3" echo  [*] Reachable on your LAN at %DISPLAY_URL%
if "%MODE%"=="2" echo  [*] Accessible only from this machine.
echo.
echo  Press Ctrl+C to stop the server.
echo.

:: 7. Launch Uvicorn using the venv
cd /d "%~dp0"
".venv\Scripts\python.exe" -m uvicorn app:asgi_app --host %BIND_HOST% --port %PORT%

:: 8. Pause if it crashes so the user can read the error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] PyStudio stopped unexpectedly.
    pause
)