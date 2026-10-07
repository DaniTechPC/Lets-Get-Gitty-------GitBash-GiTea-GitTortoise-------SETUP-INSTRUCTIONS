@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "ROOT=%~dp0"
set "DEPS=%ROOT%Batch-Dependencies\"
set "HOMEWIN=%USERPROFILE%"
set "BINDEST=%USERPROFILE%\bin"

cls
echo ============================================================
echo          Git Bash Linux-Like Environment Setup
echo ============================================================
echo.
echo This will configure Git Bash for Windows user:
echo   %USERNAME%
echo.
echo Files will be installed under:
echo   %USERPROFILE%
echo.

REM ------------------------------------------------------------
REM Verify Git for Windows exists.
REM ------------------------------------------------------------
where git.exe >nul 2>&1
if errorlevel 1 (
    if exist "%ProgramFiles%\Git\bin\git.exe" goto :git_found
    if exist "%LOCALAPPDATA%\Programs\Git\bin\git.exe" goto :git_found
    echo ERROR: Git for Windows was not found.
    echo.
    echo Install normal Git for Windows first, then run this file again.
    echo.
    pause
    exit /b 1
)
:git_found

echo [1/7] Git for Windows detected.

REM ------------------------------------------------------------
REM Verify package files exist in .\Batch-Dependencies beside this BAT.
REM ------------------------------------------------------------
for %%F in (".minttyrc" ".bashrc" ".bash_profile" "bin\apt" "bin\linux-help") do (
    if not exist "%DEPS%%%~F" (
        echo ERROR: Missing setup file: %%~F
        echo Keep this BAT beside the Batch-Dependencies folder.
        echo.
        pause
        exit /b 2
    )
)

echo [2/7] Setup files verified.

REM ------------------------------------------------------------
REM Back up old user configuration.
REM Timestamp: YYYYMMDD-HHMMSS (locale independent via PowerShell).
REM ------------------------------------------------------------
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%T"
if not defined STAMP set "STAMP=backup"
set "BACKUP=%USERPROFILE%\GitBash-Backup-%STAMP%"
mkdir "%BACKUP%" >nul 2>&1

if exist "%USERPROFILE%\.minttyrc" copy /y "%USERPROFILE%\.minttyrc" "%BACKUP%\.minttyrc" >nul
if exist "%USERPROFILE%\.bashrc" copy /y "%USERPROFILE%\.bashrc" "%BACKUP%\.bashrc" >nul
if exist "%USERPROFILE%\.bash_profile" copy /y "%USERPROFILE%\.bash_profile" "%BACKUP%\.bash_profile" >nul

echo [3/7] Existing shell settings backed up to:
echo       %BACKUP%

REM ------------------------------------------------------------
REM Install shell configuration.
REM ------------------------------------------------------------
copy /y "%DEPS%.minttyrc" "%USERPROFILE%\.minttyrc" >nul || goto :copy_error
copy /y "%DEPS%.bashrc" "%USERPROFILE%\.bashrc" >nul || goto :copy_error
copy /y "%DEPS%.bash_profile" "%USERPROFILE%\.bash_profile" >nul || goto :copy_error

if not exist "%BINDEST%" mkdir "%BINDEST%"
copy /y "%DEPS%bin\*" "%BINDEST%\" >nul || goto :copy_error

echo [4/7] Mintty theme, Bash configuration and Linux commands installed.

REM ------------------------------------------------------------
REM Enable Sudo for Windows if supported and currently disabled.
REM Windows 11 24H2+ includes sudo.exe. Existing enabled modes are
REM preserved. If disabled, use Microsoft's safer default mode:
REM forceNewWindow. Only this system-setting step is elevated.
REM ------------------------------------------------------------
echo [5/7] Checking Sudo for Windows...

if not exist "%SystemRoot%\System32\sudo.exe" (
    echo   [SKIP] Sudo for Windows is not available on this Windows version.
    echo          Windows 11 24H2 or newer is required.
    goto :sudo_done
)

set "SUDO_MODE="
for /f "tokens=3" %%S in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v Enabled 2^>nul ^| find /i "Enabled"') do set "SUDO_MODE=%%S"

if /i "%SUDO_MODE%"=="0x1" (
    echo   [OK] Sudo is already enabled - In a new window mode.
    goto :sudo_done
)
if /i "%SUDO_MODE%"=="0x2" (
    echo   [OK] Sudo is already enabled - Input closed mode.
    goto :sudo_done
)
if /i "%SUDO_MODE%"=="0x3" (
    echo   [OK] Sudo is already enabled - Inline mode.
    goto :sudo_done
)

echo   Sudo is currently disabled.
echo   Windows will ask for administrator approval to enable it.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\sudo.exe') -ArgumentList @('config','--enable','forceNewWindow') -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
if errorlevel 1 (
    echo   [WARN] Sudo could not be enabled automatically.
    echo          The rest of the Git Bash setup will continue.
    goto :sudo_done
)

set "SUDO_MODE="
for /f "tokens=3" %%S in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v Enabled 2^>nul ^| find /i "Enabled"') do set "SUDO_MODE=%%S"
if /i "%SUDO_MODE%"=="0x1" (
    echo   [OK] Sudo enabled - In a new window mode.
) else if /i "%SUDO_MODE%"=="0x2" (
    echo   [OK] Sudo enabled - Input closed mode.
) else if /i "%SUDO_MODE%"=="0x3" (
    echo   [OK] Sudo enabled - Inline mode.
) else (
    echo   [WARN] Sudo command completed, but enabled status could not be verified.
)

:sudo_done

REM ------------------------------------------------------------
REM Install a few small, familiar CLI tools through WinGet.
REM Failure of one optional tool does not stop the configuration.
REM ------------------------------------------------------------
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo [6/7] WinGet not found - skipping optional nano/wget/jq installs.
    echo       The apt wrapper is installed, but requires WinGet to install packages.
    goto :skip_tools
)

echo [6/7] Installing familiar command-line tools with WinGet...
echo.
call :install_pkg GNU.Nano nano
call :install_pkg JernejSimoncic.Wget wget
call :install_pkg jqlang.jq jq

:skip_tools
REM ------------------------------------------------------------
REM Finish.
REM ------------------------------------------------------------
echo.
echo [7/7] Setup complete.
echo.
echo ============================================================
echo  IMPORTANT: Close all Git Bash windows, then open Git Bash again.
echo ============================================================
echo.
echo Test these commands:
echo   linux-help
echo   ll
echo   nano --version
echo   wget --version
echo   jq --version
echo   ifconfig
echo   ip addr
echo   free
echo   apt update
echo   apt search python
echo.
echo Your previous configuration was backed up here:
echo   %BACKUP%
echo.
pause
exit /b 0

:install_pkg
set "PKG=%~1"
set "FRIENDLY=%~2"
winget.exe list --id "%PKG%" --exact >nul 2>&1
if not errorlevel 1 (
    echo   [OK] %FRIENDLY% is already installed.
    exit /b 0
)
echo   Installing %FRIENDLY%...
winget.exe install --id "%PKG%" --exact --silent --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo   [WARN] Could not automatically install %FRIENDLY%.
    echo          You can try later from Git Bash: apt install %FRIENDLY%
) else (
    echo   [OK] %FRIENDLY% installed.
)
exit /b 0

:copy_error
echo.
echo ERROR: Could not copy one or more configuration files.
echo Check permissions and make sure the setup folder is complete.
echo.
pause
exit /b 3
