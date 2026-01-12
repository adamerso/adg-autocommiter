@echo off
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════
:: ADG Auto-Commiter Launcher v1.0
:: Downloads latest version and runs in Cygwin mintty
:: Just double-click to run!
:: ═══════════════════════════════════════════════════════════════════════════

title ADG Auto-Commiter Launcher

:: Colors for pretty output
set "GREEN=[92m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RED=[91m"
set "RESET=[0m"

echo.
echo %CYAN%╔══════════════════════════════════════════════════════════════╗%RESET%
echo %CYAN%║%RESET%  %GREEN%ADG Auto-Commiter Launcher%RESET%                                 %CYAN%║%RESET%
echo %CYAN%║%RESET%  Downloads latest version and runs in Cygwin mintty         %CYAN%║%RESET%
echo %CYAN%╚══════════════════════════════════════════════════════════════╝%RESET%
echo.

:: Get current directory (where this launcher is)
set "LAUNCH_DIR=%~dp0"
set "LAUNCH_DIR=%LAUNCH_DIR:~0,-1%"
set "SCRIPT_NAME=adg-autocommiter-continous.sh"
set "SCRIPT_PATH=%LAUNCH_DIR%\%SCRIPT_NAME%"

:: GitHub URLs
set "GITHUB_RAW=https://raw.githubusercontent.com/adamerso/adg-autocommiter/autocommit"
set "VERSION_URL=%GITHUB_RAW%/VERSION"
set "SCRIPT_URL=%GITHUB_RAW%/adg-autocommiter-continous.sh"

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 1: Find Cygwin installation
:: ═══════════════════════════════════════════════════════════════════════════
echo %YELLOW%[1/3]%RESET% Searching for Cygwin installation...

set "CYGWIN_ROOT="
set "MINTTY="

:: List of possible Cygwin locations
set "CYGWIN_PATHS="
set "CYGWIN_PATHS=%CYGWIN_PATHS% %USERPROFILE%\cygwin64"
set "CYGWIN_PATHS=%CYGWIN_PATHS% %USERPROFILE%\cygwin"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\cygwin64"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\cygwin"
set "CYGWIN_PATHS=%CYGWIN_PATHS% D:\cygwin64"
set "CYGWIN_PATHS=%CYGWIN_PATHS% D:\cygwin"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\Program Files\cygwin64"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\Program Files\cygwin"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\Program Files (x86)\cygwin64"
set "CYGWIN_PATHS=%CYGWIN_PATHS% C:\Program Files (x86)\cygwin"

for %%P in (%CYGWIN_PATHS%) do (
    if exist "%%~P\bin\mintty.exe" (
        set "CYGWIN_ROOT=%%~P"
        set "MINTTY=%%~P\bin\mintty.exe"
        echo %GREEN%  Found Cygwin: %%~P%RESET%
        goto :found_cygwin
    )
)

:: Not found - show error
echo.
echo %RED%ERROR: Cygwin not found!%RESET%
echo.
echo Searched in:
for %%P in (%CYGWIN_PATHS%) do (
    echo   - %%~P
)
echo.
echo Please install Cygwin from: https://cygwin.com/install.html
echo Or set CYGWIN_ROOT environment variable to your Cygwin path.
echo.
pause
exit /b 1

:found_cygwin

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 2: Download/Update script from GitHub
:: ═══════════════════════════════════════════════════════════════════════════
echo %YELLOW%[2/3]%RESET% Checking for updates from GitHub...

:: Check if we have curl (usually available on Windows 10+)
where curl >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "USE_CURL=1"
) else (
    set "USE_CURL=0"
)

:: Get remote version
set "REMOTE_VERSION="
if "%USE_CURL%"=="1" (
    for /f "delims=" %%V in ('curl -sL --connect-timeout 5 "%VERSION_URL%" 2^>nul') do set "REMOTE_VERSION=%%V"
) else (
    for /f "delims=" %%V in ('powershell -Command "(Invoke-WebRequest -Uri '%VERSION_URL%' -TimeoutSec 5 -UseBasicParsing).Content" 2^>nul') do set "REMOTE_VERSION=%%V"
)

:: Get local version if exists
set "LOCAL_VERSION="
if exist "%SCRIPT_PATH%" (
    for /f "tokens=2 delims==" %%V in ('findstr /B "VERSION=" "%SCRIPT_PATH%" 2^>nul') do (
        set "LOCAL_VERSION=%%V"
        set "LOCAL_VERSION=!LOCAL_VERSION:"=!"
    )
)

echo   Remote version: %REMOTE_VERSION%
echo   Local version:  %LOCAL_VERSION%

:: Decide if we need to download
set "NEED_DOWNLOAD=0"
if not exist "%SCRIPT_PATH%" (
    echo %YELLOW%  Script not found, downloading...%RESET%
    set "NEED_DOWNLOAD=1"
) else if not "%REMOTE_VERSION%"=="" (
    if not "%REMOTE_VERSION%"=="%LOCAL_VERSION%" (
        echo %YELLOW%  New version available, updating...%RESET%
        set "NEED_DOWNLOAD=1"
    ) else (
        echo %GREEN%  Already up to date!%RESET%
    )
)

:: Download if needed
if "%NEED_DOWNLOAD%"=="1" (
    if "%USE_CURL%"=="1" (
        curl -sL --connect-timeout 10 -o "%SCRIPT_PATH%" "%SCRIPT_URL%" 2>nul
    ) else (
        powershell -Command "Invoke-WebRequest -Uri '%SCRIPT_URL%' -OutFile '%SCRIPT_PATH%' -TimeoutSec 30 -UseBasicParsing" 2>nul
    )
    
    if exist "%SCRIPT_PATH%" (
        echo %GREEN%  Downloaded successfully!%RESET%
    ) else (
        echo %RED%  Download failed!%RESET%
        if not exist "%SCRIPT_PATH%" (
            echo %RED%ERROR: No script available to run.%RESET%
            pause
            exit /b 1
        )
    )
)

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 3: Launch mintty with the script
:: ═══════════════════════════════════════════════════════════════════════════
echo %YELLOW%[3/3]%RESET% Launching ADG Auto-Commiter in mintty...

:: Convert Windows path to Cygwin path
set "CYGWIN_SCRIPT_PATH=%SCRIPT_PATH:\=/%"
set "CYGWIN_SCRIPT_PATH=%CYGWIN_SCRIPT_PATH:C:=/cygdrive/c%"
set "CYGWIN_SCRIPT_PATH=%CYGWIN_SCRIPT_PATH:D:=/cygdrive/d%"
set "CYGWIN_SCRIPT_PATH=%CYGWIN_SCRIPT_PATH:E:=/cygdrive/e%"
set "CYGWIN_SCRIPT_PATH=%CYGWIN_SCRIPT_PATH:F:=/cygdrive/f%"

:: Convert launch directory to Cygwin path (for working dir)
set "CYGWIN_LAUNCH_DIR=%LAUNCH_DIR:\=/%"
set "CYGWIN_LAUNCH_DIR=%CYGWIN_LAUNCH_DIR:C:=/cygdrive/c%"
set "CYGWIN_LAUNCH_DIR=%CYGWIN_LAUNCH_DIR:D:=/cygdrive/d%"
set "CYGWIN_LAUNCH_DIR=%CYGWIN_LAUNCH_DIR:E:=/cygdrive/e%"
set "CYGWIN_LAUNCH_DIR=%CYGWIN_LAUNCH_DIR:F:=/cygdrive/f%"

echo.
echo %GREEN%Starting: %SCRIPT_NAME%%RESET%
echo %CYAN%Directory: %LAUNCH_DIR%%RESET%
echo.

:: Launch mintty with bash running the script
:: -i = roles icon, -t = title, - = run login shell
start "" "%MINTTY%" -i /Cygwin-Terminal.ico -t "ADG Auto-Commiter" /bin/bash -l -c "cd '%CYGWIN_LAUNCH_DIR%' && bash '%CYGWIN_SCRIPT_PATH%'"

:: Success!
echo %GREEN%Launched! You can close this window.%RESET%
echo.

:: Auto-close after 3 seconds
timeout /t 3 >nul

exit /b 0
