@echo off
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════
:: ADG Auto-Commiter Launcher v1.1
:: Downloads latest version and runs in Cygwin mintty
:: Self-updates from GitHub!
:: ═══════════════════════════════════════════════════════════════════════════

set "LAUNCHER_VERSION=1.1"

title ADG Auto-Commiter Launcher v%LAUNCHER_VERSION%

:: Colors for pretty output
set "GREEN=[92m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RED=[91m"
set "MAGENTA=[95m"
set "RESET=[0m"

:: Get current directory and launcher path
set "LAUNCH_DIR=%~dp0"
set "LAUNCH_DIR=%LAUNCH_DIR:~0,-1%"
set "LAUNCHER_PATH=%~f0"
set "LAUNCHER_NAME=%~nx0"
set "SCRIPT_NAME=adg-autocommiter-continous.sh"
set "SCRIPT_PATH=%LAUNCH_DIR%\%SCRIPT_NAME%"

:: GitHub URLs
set "GITHUB_RAW=https://raw.githubusercontent.com/adamerso/adg-autocommiter/autocommit"
set "VERSION_URL=%GITHUB_RAW%/VERSION"
set "SCRIPT_URL=%GITHUB_RAW%/adg-autocommiter-continous.sh"
set "LAUNCHER_URL=%GITHUB_RAW%/adg-autocommiter-launcher.cmd"
set "LAUNCHER_VERSION_URL=%GITHUB_RAW%/LAUNCHER_VERSION"

:: Check if we have curl
where curl >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "USE_CURL=1"
) else (
    set "USE_CURL=0"
)

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 0: Self-update launcher
:: ═══════════════════════════════════════════════════════════════════════════
:: Skip if already relaunched (prevent infinite loop)
if "%ADG_RELAUNCHED%"=="1" goto :skip_self_update

echo.
echo %MAGENTA%[0/4]%RESET% Checking for launcher updates...

set "REMOTE_LAUNCHER_VERSION="
if "%USE_CURL%"=="1" (
    for /f "delims=" %%V in ('curl -sL --connect-timeout 3 "%LAUNCHER_VERSION_URL%" 2^>nul') do set "REMOTE_LAUNCHER_VERSION=%%V"
) else (
    for /f "delims=" %%V in ('powershell -Command "(Invoke-WebRequest -Uri '%LAUNCHER_VERSION_URL%' -TimeoutSec 3 -UseBasicParsing).Content.Trim()" 2^>nul') do set "REMOTE_LAUNCHER_VERSION=%%V"
)

if "%REMOTE_LAUNCHER_VERSION%"=="" (
    echo %YELLOW%  Could not check launcher version%RESET%
    goto :skip_self_update
)

echo   Launcher: v%LAUNCHER_VERSION% / Remote: v%REMOTE_LAUNCHER_VERSION%

if "%REMOTE_LAUNCHER_VERSION%"=="%LAUNCHER_VERSION%" (
    echo %GREEN%  Launcher up to date%RESET%
    goto :skip_self_update
)

:: Download new launcher to temp file
echo %YELLOW%  New launcher available, updating...%RESET%
set "TEMP_LAUNCHER=%TEMP%\adg-launcher-new-%RANDOM%.cmd"

if "%USE_CURL%"=="1" (
    curl -sL --connect-timeout 10 -o "%TEMP_LAUNCHER%" "%LAUNCHER_URL%" 2>nul
) else (
    powershell -Command "Invoke-WebRequest -Uri '%LAUNCHER_URL%' -OutFile '%TEMP_LAUNCHER%' -TimeoutSec 15 -UseBasicParsing" 2>nul
)

if not exist "%TEMP_LAUNCHER%" (
    echo %RED%  Download failed, continuing with current version%RESET%
    goto :skip_self_update
)

:: Create relaunch script that replaces launcher and restarts
set "RELAUNCH_SCRIPT=%TEMP%\adg-relaunch-%RANDOM%.cmd"
(
    echo @echo off
    echo timeout /t 1 /nobreak ^>nul
    echo copy /Y "%TEMP_LAUNCHER%" "%LAUNCHER_PATH%" ^>nul
    echo del "%TEMP_LAUNCHER%" ^>nul 2^>^&1
    echo set "ADG_RELAUNCHED=1"
    echo cd /d "%LAUNCH_DIR%"
    echo call "%LAUNCHER_PATH%"
    echo del "%RELAUNCH_SCRIPT%" ^>nul 2^>^&1
) > "%RELAUNCH_SCRIPT%"

echo %GREEN%  Downloaded v%REMOTE_LAUNCHER_VERSION%, relaunching...%RESET%
start "" cmd /c "%RELAUNCH_SCRIPT%"
exit /b 0

:skip_self_update

echo.
echo %CYAN%╔══════════════════════════════════════════════════════════════╗%RESET%
echo %CYAN%║%RESET%  %GREEN%ADG Auto-Commiter Launcher v%LAUNCHER_VERSION%%RESET%                          %CYAN%║%RESET%
echo %CYAN%║%RESET%  Downloads latest version and runs in Cygwin mintty         %CYAN%║%RESET%
echo %CYAN%╚══════════════════════════════════════════════════════════════╝%RESET%
echo.

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 1: Find Cygwin installation
:: ═══════════════════════════════════════════════════════════════════════════
echo %YELLOW%[1/4]%RESET% Searching for Cygwin installation...

set "CYGWIN_ROOT="
set "MINTTY="

:: Check each location one by one
if exist "%USERPROFILE%\cygwin64\bin\mintty.exe" (
    set "CYGWIN_ROOT=%USERPROFILE%\cygwin64"
    goto :found_cygwin
)
if exist "%USERPROFILE%\cygwin\bin\mintty.exe" (
    set "CYGWIN_ROOT=%USERPROFILE%\cygwin"
    goto :found_cygwin
)
if exist "C:\cygwin64\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\cygwin64"
    goto :found_cygwin
)
if exist "C:\cygwin\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\cygwin"
    goto :found_cygwin
)
if exist "D:\cygwin64\bin\mintty.exe" (
    set "CYGWIN_ROOT=D:\cygwin64"
    goto :found_cygwin
)
if exist "D:\cygwin\bin\mintty.exe" (
    set "CYGWIN_ROOT=D:\cygwin"
    goto :found_cygwin
)
if exist "C:\Program Files\cygwin64\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\Program Files\cygwin64"
    goto :found_cygwin
)
if exist "C:\Program Files\cygwin\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\Program Files\cygwin"
    goto :found_cygwin
)
if exist "C:\Program Files (x86)\cygwin64\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\Program Files (x86)\cygwin64"
    goto :found_cygwin
)
if exist "C:\Program Files (x86)\cygwin\bin\mintty.exe" (
    set "CYGWIN_ROOT=C:\Program Files (x86)\cygwin"
    goto :found_cygwin
)

:: Not found - show error
echo.
echo %RED%ERROR: Cygwin not found!%RESET%
echo.
echo Searched in:
echo   - %USERPROFILE%\cygwin64
echo   - %USERPROFILE%\cygwin
echo   - C:\cygwin64, C:\cygwin
echo   - D:\cygwin64, D:\cygwin
echo   - C:\Program Files\cygwin64
echo   - C:\Program Files (x86)\cygwin64
echo.
echo Please install Cygwin from: https://cygwin.com/install.html
echo.
pause
exit /b 1

:found_cygwin
set "MINTTY=%CYGWIN_ROOT%\bin\mintty.exe"
echo %GREEN%  Found Cygwin: %CYGWIN_ROOT%%RESET%

:: ═══════════════════════════════════════════════════════════════════════════
:: STEP 2: Download/Update script from GitHub
:: ═══════════════════════════════════════════════════════════════════════════
echo %YELLOW%[2/4]%RESET% Checking for script updates...

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
echo %YELLOW%[3/4]%RESET% Launching ADG Auto-Commiter in mintty...

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
