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
REM Verify Git for Windows exists AND make sure normal Windows CMD
REM can recognize the "git" command.
REM
REM If Git is installed but its \cmd folder is missing from PATH,
REM this setup adds it to the CURRENT USER'S Windows PATH.
REM ------------------------------------------------------------
echo [1/8] Checking Git for Windows and Windows CMD PATH...

where git.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%V in ('git --version 2^>nul') do set "GIT_VERSION=%%V"
    echo   [OK] Git is already recognized by Windows CMD.
    if defined GIT_VERSION echo        !GIT_VERSION!
    goto :git_ready
)

echo   Git is installed or expected, but "git" is not currently recognized.
echo   Looking for the Git for Windows installation...

call :find_git_cmd

if not defined GITCMDDIR (
    echo.
    echo ERROR: Git for Windows was not found.
    echo.
    echo Install normal Git for Windows first, then run this file again.
    echo.
    pause
    exit /b 1
)

echo   [FOUND] %GITCMDDIR%
echo   Adding this folder to the current user's Windows PATH...

REM Use PowerShell/.NET instead of SETX so an existing long PATH is not truncated.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$g=$env:GITCMDDIR; $p=[Environment]::GetEnvironmentVariable('Path','User'); if([string]::IsNullOrWhiteSpace($p)){[Environment]::SetEnvironmentVariable('Path',$g,'User'); exit 0}; $found=$false; foreach($x in ($p -split ';')){if($x.Trim().TrimEnd('\') -ieq $g.TrimEnd('\')){$found=$true; break}}; if(-not $found){[Environment]::SetEnvironmentVariable('Path',$p.TrimEnd(';')+';'+$g,'User')}" >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Git was found, but its CMD folder could not be added to PATH.
    echo       Git folder: %GITCMDDIR%
    echo.
    pause
    exit /b 1
)

REM Make Git available to this running BAT immediately too.
set "PATH=%GITCMDDIR%;%PATH%"

where git.exe >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Git PATH was updated, but "git" still could not be verified.
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%V in ('git --version 2^>nul') do set "GIT_VERSION=%%V"
echo   [OK] Git has been added to the Windows user PATH.
if defined GIT_VERSION echo        !GIT_VERSION!
echo   [OK] New CMD windows will recognize the "git" command.

:git_ready

REM ------------------------------------------------------------
REM Verify package files exist in .\Batch-Dependencies beside this BAT.
REM ------------------------------------------------------------
for %%F in (".minttyrc" ".bashrc" ".bash_profile" "bin\apt" "bin\linux-help" "bin\wget") do (
    if not exist "%DEPS%%%~F" (
        echo ERROR: Missing setup file: %%~F
        echo Keep this BAT beside the Batch-Dependencies folder.
        echo.
        pause
        exit /b 2
    )
)

echo [2/8] Setup files verified.

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

echo [3/8] Existing shell settings backed up to:
echo       %BACKUP%

REM ------------------------------------------------------------
REM Install shell configuration.
REM ------------------------------------------------------------
copy /y "%DEPS%.minttyrc" "%USERPROFILE%\.minttyrc" >nul || goto :copy_error
copy /y "%DEPS%.bashrc" "%USERPROFILE%\.bashrc" >nul || goto :copy_error
copy /y "%DEPS%.bash_profile" "%USERPROFILE%\.bash_profile" >nul || goto :copy_error

if not exist "%BINDEST%" mkdir "%BINDEST%"
copy /y "%DEPS%bin\*" "%BINDEST%\" >nul || goto :copy_error

echo [4/8] Mintty theme, Bash configuration and Linux commands installed.

REM ------------------------------------------------------------
REM Enable Sudo for Windows if supported and currently disabled.
REM Windows 11 24H2+ includes sudo.exe. Existing enabled modes are
REM preserved. If disabled, use Microsoft's safer default mode:
REM forceNewWindow. Only this system-setting step is elevated.
REM ------------------------------------------------------------
echo [5/8] Checking Sudo for Windows...

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
REM WinGet is NOT used during base setup.
REM It is detected only because the apt compatibility wrapper can use it
REM later if the user explicitly runs "apt install ...".
REM ------------------------------------------------------------
echo [6/8] Checking optional WinGet backend for apt...
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo   [INFO] WinGet is not currently available.
    echo          Git Bash will still work normally.
    echo          Only "apt install" package installation will be unavailable.
) else (
    for /f "delims=" %%V in ('winget.exe --version 2^>nul') do set "WINGET_VERSION=%%V"
    echo   [OK] WinGet backend detected for optional apt package installs.
    if defined WINGET_VERSION echo        !WINGET_VERSION!
)

REM ------------------------------------------------------------
REM Final Git/CMD verification.
REM ------------------------------------------------------------
echo.
echo [7/8] Verifying Git command for Windows CMD...
where git.exe >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Git could not be found in this setup process.
    echo          Close this window and open a NEW Command Prompt, then try:
    echo            git --version
) else (
    for /f "delims=" %%V in ('git --version 2^>nul') do set "GIT_VERSION=%%V"
    echo   [OK] git command recognized.
    if defined GIT_VERSION echo        !GIT_VERSION!
)

REM ------------------------------------------------------------
REM Finish.
REM ------------------------------------------------------------
echo.
echo [8/8] Setup complete.
echo.
echo ============================================================
echo  IMPORTANT: Close all Git Bash windows, then open Git Bash again.
echo ============================================================
echo.
echo Test Windows CMD after opening a NEW Command Prompt:
echo   git --version
echo.
echo Test these Git Bash commands:
echo   linux-help
echo   ll
echo   nano --version
echo   wget --version
echo   linux-check
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

:find_git_cmd
set "GITCMDDIR="

REM Most common machine-wide Git for Windows location.
if exist "%ProgramFiles%\Git\cmd\git.exe" (
    set "GITCMDDIR=%ProgramFiles%\Git\cmd"
    exit /b 0
)

REM Less-common 32-bit installation.
if defined ProgramFiles(x86) if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" (
    set "GITCMDDIR=%ProgramFiles(x86)%\Git\cmd"
    exit /b 0
)

REM Common per-user Git for Windows installation.
if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" (
    set "GITCMDDIR=%LOCALAPPDATA%\Programs\Git\cmd"
    exit /b 0
)

REM Also check Git for Windows' registry InstallPath in case Git was
REM installed to a custom directory.
for %%K in (
    "HKLM\SOFTWARE\GitForWindows"
    "HKCU\SOFTWARE\GitForWindows"
    "HKLM\SOFTWARE\WOW6432Node\GitForWindows"
) do (
    for /f "tokens=1,2,*" %%A in ('reg.exe query "%%~K" /v InstallPath 2^>nul ^| find /i "InstallPath"') do (
        if /i "%%A"=="InstallPath" (
            if exist "%%C\cmd\git.exe" (
                set "GITCMDDIR=%%C\cmd"
                exit /b 0
            )
        )
    )
)

exit /b 1

:copy_error
echo.
echo ERROR: Could not copy one or more configuration files.
echo Check permissions and make sure the setup folder is complete.
echo.
pause
exit /b 3
