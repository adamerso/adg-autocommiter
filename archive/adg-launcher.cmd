@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM ADG AUTO-COMMITER LAUNCHER v1.0
REM ═══════════════════════════════════════════════════════════════════════════
REM Finds Cygwin/Git Bash/WSL and launches auto-commiter with retry mechanism
REM Retry intervals: 1, 5, 15, 30, 60, 120, then 240s forever
REM ═══════════════════════════════════════════════════════════════════════════

setlocal EnableDelayedExpansion

REM Get script directory (where this launcher lives)
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Auto-commiter script name
set "AC_SCRIPT=adg-auto-commiter-UpNext.sh"
set "AC_FALLBACK=auto-commiter5.sh"

REM Check which script exists
if exist "%SCRIPT_DIR%\%AC_SCRIPT%" (
    set "TARGET_SCRIPT=%AC_SCRIPT%"
) else if exist "%SCRIPT_DIR%\%AC_FALLBACK%" (
    set "TARGET_SCRIPT=%AC_FALLBACK%"
) else (
    echo [ERROR] No auto-commiter script found!
    echo Looked for: %AC_SCRIPT% and %AC_FALLBACK%
    pause
    exit /b 1
)

echo ═══════════════════════════════════════════════════════════════════════════
echo  ADG AUTO-COMMITER LAUNCHER
echo ═══════════════════════════════════════════════════════════════════════════
echo  Script Dir: %SCRIPT_DIR%
echo  Target:     %TARGET_SCRIPT%
echo ═══════════════════════════════════════════════════════════════════════════

REM ═══════════════════════════════════════════════════════════════════════════
REM SHELL DETECTION - Find available bash environment
REM Priority: Cygwin mintty ^> Git Bash ^> WSL ^> Windows Bash
REM ═══════════════════════════════════════════════════════════════════════════

set "SHELL_TYPE="
set "SHELL_PATH="
set "MINTTY_PATH="
set "BASH_PATH="

REM --- Check Cygwin locations ---
echo [DETECT] Searching for Cygwin...

REM 1. C:\cygwin64\bin
if exist "C:\cygwin64\bin\bash.exe" (
    set "SHELL_TYPE=CYGWIN64"
    set "BASH_PATH=C:\cygwin64\bin\bash.exe"
    if exist "C:\cygwin64\bin\mintty.exe" set "MINTTY_PATH=C:\cygwin64\bin\mintty.exe"
    goto :found_shell
)

REM 2. %USERPROFILE%\cygwin64\bin
if exist "%USERPROFILE%\cygwin64\bin\bash.exe" (
    set "SHELL_TYPE=CYGWIN64_USER"
    set "BASH_PATH=%USERPROFILE%\cygwin64\bin\bash.exe"
    if exist "%USERPROFILE%\cygwin64\bin\mintty.exe" set "MINTTY_PATH=%USERPROFILE%\cygwin64\bin\mintty.exe"
    goto :found_shell
)

REM 3. C:\cygwin\bin
if exist "C:\cygwin\bin\bash.exe" (
    set "SHELL_TYPE=CYGWIN32"
    set "BASH_PATH=C:\cygwin\bin\bash.exe"
    if exist "C:\cygwin\bin\mintty.exe" set "MINTTY_PATH=C:\cygwin\bin\mintty.exe"
    goto :found_shell
)

REM 4. %USERPROFILE%\cygwin\bin
if exist "%USERPROFILE%\cygwin\bin\bash.exe" (
    set "SHELL_TYPE=CYGWIN32_USER"
    set "BASH_PATH=%USERPROFILE%\cygwin\bin\bash.exe"
    if exist "%USERPROFILE%\cygwin\bin\mintty.exe" set "MINTTY_PATH=%USERPROFILE%\cygwin\bin\mintty.exe"
    goto :found_shell
)

REM --- Check Git Bash locations ---
echo [DETECT] Searching for Git Bash...

REM 5. Git Bash standard locations
if exist "C:\Program Files\Git\bin\bash.exe" (
    set "SHELL_TYPE=GIT_BASH"
    set "BASH_PATH=C:\Program Files\Git\bin\bash.exe"
    if exist "C:\Program Files\Git\usr\bin\mintty.exe" set "MINTTY_PATH=C:\Program Files\Git\usr\bin\mintty.exe"
    goto :found_shell
)

if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    set "SHELL_TYPE=GIT_BASH_X86"
    set "BASH_PATH=C:\Program Files (x86)\Git\bin\bash.exe"
    goto :found_shell
)

REM 6. Git from PATH
where git.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('where git.exe') do (
        set "GIT_EXE=%%i"
        goto :got_git_path
    )
    :got_git_path
    REM Extract Git directory and find bash
    for %%a in ("!GIT_EXE!") do set "GIT_DIR=%%~dpa"
    if exist "!GIT_DIR!bash.exe" (
        set "SHELL_TYPE=GIT_BASH_PATH"
        set "BASH_PATH=!GIT_DIR!bash.exe"
        goto :found_shell
    )
)

REM --- Check WSL ---
echo [DETECT] Searching for WSL...

where wsl.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "SHELL_TYPE=WSL"
    set "BASH_PATH=wsl.exe"
    goto :found_shell
)

REM --- Check Windows Bash (WSL legacy) ---
if exist "%SYSTEMROOT%\System32\bash.exe" (
    set "SHELL_TYPE=WIN_BASH"
    set "BASH_PATH=%SYSTEMROOT%\System32\bash.exe"
    goto :found_shell
)

REM --- No shell found ---
echo [ERROR] No compatible shell found!
echo Checked: Cygwin, Git Bash, WSL, Windows Bash
pause
exit /b 1

:found_shell
echo [OK] Found: %SHELL_TYPE%
echo      Bash:   %BASH_PATH%
if defined MINTTY_PATH echo      Mintty: %MINTTY_PATH%
echo.

REM ═══════════════════════════════════════════════════════════════════════════
REM CONVERT WINDOWS PATH TO UNIX PATH
REM ═══════════════════════════════════════════════════════════════════════════

REM Convert script directory to Unix path
set "UNIX_DIR=%SCRIPT_DIR%"
set "UNIX_DIR=%UNIX_DIR:\=/%"

REM Handle drive letter for Cygwin/Git Bash
set "DRIVE_LETTER=%UNIX_DIR:~0,1%"
set "UNIX_DIR_REST=%UNIX_DIR:~2%"

if "%SHELL_TYPE:~0,6%"=="CYGWIN" (
    set "UNIX_WORKDIR=/cygdrive/%DRIVE_LETTER%%UNIX_DIR_REST%"
) else if "%SHELL_TYPE:~0,8%"=="GIT_BASH" (
    set "UNIX_WORKDIR=/%DRIVE_LETTER%%UNIX_DIR_REST%"
) else (
    REM WSL uses /mnt/c style
    set "UNIX_WORKDIR=/mnt/%DRIVE_LETTER%%UNIX_DIR_REST%"
)

REM Make drive letter lowercase
set "UNIX_WORKDIR=%UNIX_WORKDIR:A=a%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:B=b%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:C=c%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:D=d%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:E=e%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:F=f%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:G=g%"
set "UNIX_WORKDIR=%UNIX_WORKDIR:H=h%"

echo [PATH] Unix workdir: %UNIX_WORKDIR%
echo.

REM ═══════════════════════════════════════════════════════════════════════════
REM RETRY LOOP WITH EXPONENTIAL BACKOFF
REM Intervals: 1, 5, 15, 30, 60, 120, then 240 forever
REM ═══════════════════════════════════════════════════════════════════════════

set "RETRY_COUNT=0"
set "RETRY_INTERVALS=1 5 15 30 60 120 240"

:retry_loop
set /a RETRY_COUNT+=1

echo ═══════════════════════════════════════════════════════════════════════════
echo  [LAUNCH] Attempt #%RETRY_COUNT% - %date% %time%
echo ═══════════════════════════════════════════════════════════════════════════

REM Build the bash command
set "BASH_CMD=cd '%UNIX_WORKDIR%' && bash './%TARGET_SCRIPT%'"

REM Launch based on shell type
if defined MINTTY_PATH (
    echo [RUN] Using mintty terminal...
    "%MINTTY_PATH%" -t "ADG Auto-Commiter" -e /bin/bash -c "%BASH_CMD%"
    set "EXIT_CODE=%ERRORLEVEL%"
) else if "%SHELL_TYPE%"=="WSL" (
    echo [RUN] Using WSL...
    start "ADG Auto-Commiter" cmd /c "wsl.exe bash -c ""%BASH_CMD%"" & pause"
    set "EXIT_CODE=%ERRORLEVEL%"
) else (
    echo [RUN] Using bash directly...
    start "ADG Auto-Commiter" cmd /c ""%BASH_PATH%" -c "%BASH_CMD%" & pause"
    set "EXIT_CODE=%ERRORLEVEL%"
)

REM Check if launch failed immediately
if %EXIT_CODE% NEQ 0 (
    echo [WARN] Launch returned error code: %EXIT_CODE%
    goto :do_retry
)

REM Wait a moment to see if process crashes immediately
timeout /t 3 /nobreak >nul

REM For mintty, check if process is still running
if defined MINTTY_PATH (
    tasklist /fi "imagename eq mintty.exe" 2>nul | find /i "mintty.exe" >nul
    if %ERRORLEVEL% NEQ 0 (
        echo [WARN] mintty process died immediately
        goto :do_retry
    )
)

echo [OK] Auto-commiter launched successfully!
echo [INFO] This launcher will now exit. Auto-commiter is running in its own window.
timeout /t 5
exit /b 0

:do_retry
REM Calculate retry interval
set "INTERVAL=240"
set "IDX=0"
for %%i in (%RETRY_INTERVALS%) do (
    set /a IDX+=1
    if !IDX! EQU %RETRY_COUNT% set "INTERVAL=%%i"
)

echo.
echo [RETRY] Auto-commiter crashed or failed to start!
echo [RETRY] Waiting %INTERVAL% seconds before retry #%RETRY_COUNT%...
echo [RETRY] Press Ctrl+C to abort
echo.

timeout /t %INTERVAL%

goto :retry_loop
