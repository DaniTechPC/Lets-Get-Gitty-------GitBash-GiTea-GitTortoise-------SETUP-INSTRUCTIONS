@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Create Gitea Web Desktop Shortcut

REM ============================================================
REM Gitea Web Shortcut Creator
REM
REM Required files beside this BAT:
REM   Create-Gitea-Web-Shortcut.bat
REM   Batch-Dependencies\Gitea.ico
REM
REM This script dynamically reads the Gitea URL from:
REM   <current drive>:\Gitea\custom\conf\app.ini
REM ============================================================

set "TARGET_DRIVE=%~d0"
set "APPINI=%TARGET_DRIVE%\Gitea\custom\conf\app.ini"
set "SHORTCUT_NAME=Gitea WEB.lnk"

REM 0 = create shortcut only for the currently logged-in user
REM 1 = create shortcut for all users on this PC, requires admin
set "CREATE_FOR_ALL_USERS=0"

set "SOURCE_ICON=%~dp0Batch-Dependencies\Gitea.ico"
set "LOCAL_ICON_DIR=%LOCALAPPDATA%\GiteaWebShortcut"
set "LOCAL_ICON=%LOCAL_ICON_DIR%\Gitea.ico"

if "%CREATE_FOR_ALL_USERS%"=="1" (
    set "LOCAL_ICON_DIR=C:\ProgramData\GiteaWebShortcut"
    set "LOCAL_ICON=C:\ProgramData\GiteaWebShortcut\Gitea.ico"
)

cls
echo.
echo ==========================================
echo   Creating Gitea Web Desktop Shortcut
echo ==========================================
echo.
echo Target config:
echo   %APPINI%
echo.

if not exist "%APPINI%" (
    echo ERROR: Could not find Gitea config:
    echo   "%APPINI%"
    echo.
    echo Make sure Gitea is installed and fully configured first.
    echo.
    pause
    exit /b 1
)

if not exist "%SOURCE_ICON%" (
    echo ERROR: Could not find icon file:
    echo   "%SOURCE_ICON%"
    echo.
    echo Keep Gitea.ico inside the Batch-Dependencies folder beside this BAT.
    echo.
    pause
    exit /b 1
)

if "%CREATE_FOR_ALL_USERS%"=="1" (
    net session >nul 2>nul
    if errorlevel 1 (
        echo ERROR: All-users mode requires administrator permission.
        echo.
        echo Right-click this batch file and choose "Run as administrator",
        echo or edit CREATE_FOR_ALL_USERS back to 0.
        echo.
        pause
        exit /b 1
    )
)

echo Reading URL from Gitea config...
for /f "usebackq delims=" %%U in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path=$env:APPINI;" ^
  "if(-not (Test-Path -LiteralPath $path)){ exit 1 };" ^
  "$lines=Get-Content -LiteralPath $path;" ^
  "$inServer=$false; $vals=@{};" ^
  "foreach($line in $lines){ $trim=$line.Trim(); if($trim -match '^\[(.+)\]$'){ $inServer=($matches[1].Trim().ToLower() -eq 'server'); continue }; if(-not $inServer){ continue }; if($trim -eq '' -or $trim.StartsWith(';') -or $trim.StartsWith('#')){ continue }; if($trim -match '^\s*([^=]+?)\s*=\s*(.*)\s*$'){ $k=$matches[1].Trim().ToUpperInvariant(); $v=$matches[2].Trim(); if(-not $vals.ContainsKey($k)){ $vals[$k]=$v } } };" ^
  "$url='';" ^
  "if($vals.ContainsKey('ROOT_URL') -and $vals['ROOT_URL']){ $url=$vals['ROOT_URL'] } else { $protocol='http'; if($vals.ContainsKey('PROTOCOL') -and $vals['PROTOCOL']){ $protocol=$vals['PROTOCOL'] }; $domain=''; if($vals.ContainsKey('DOMAIN') -and $vals['DOMAIN']){ $domain=$vals['DOMAIN'] }; $port=''; if($vals.ContainsKey('HTTP_PORT') -and $vals['HTTP_PORT']){ $port=$vals['HTTP_PORT'] }; if($domain){ if(($protocol -ieq 'http' -and $port -and $port -ne '80') -or ($protocol -ieq 'https' -and $port -and $port -ne '443') -or (($protocol -ine 'http' -and $protocol -ine 'https') -and $port)){ $url = $protocol + '://' + $domain + ':' + $port + '/' } else { $url = $protocol + '://' + $domain + '/' } } };" ^
  "if(-not $url){ exit 2 };" ^
  "Write-Output $url"` ) do set "URL=%%U"

if not defined URL (
    echo.
    echo ERROR: Could not determine the Gitea web URL from app.ini
    echo.
    echo Check the [server] section in:
    echo   %APPINI%
    echo.
    echo Expected either:
    echo   ROOT_URL = ...
    echo or values such as:
    echo   PROTOCOL = http
    echo   DOMAIN = yourserver
    echo   HTTP_PORT = 3000
    echo.
    pause
    exit /b 1
)

echo URL found:
echo   %URL%
echo.

if not exist "%LOCAL_ICON_DIR%" mkdir "%LOCAL_ICON_DIR%" >nul 2>&1
copy /Y "%SOURCE_ICON%" "%LOCAL_ICON%" >nul
if errorlevel 1 (
    echo ERROR: Could not copy icon to:
    echo   "%LOCAL_ICON%"
    echo.
    pause
    exit /b 1
)

set "DESKTOP_DIR=%USERPROFILE%\Desktop"
if "%CREATE_FOR_ALL_USERS%"=="1" (
    set "DESKTOP_DIR=C:\Users\Public\Desktop"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ShortcutPath = Join-Path $env:DESKTOP_DIR $env:SHORTCUT_NAME;" ^
  "$Shell = New-Object -ComObject WScript.Shell;" ^
  "$Shortcut = $Shell.CreateShortcut($ShortcutPath);" ^
  "$Shortcut.TargetPath = Join-Path $env:WINDIR 'explorer.exe';" ^
  "$Shortcut.Arguments = $env:URL;" ^
  "$Shortcut.WorkingDirectory = $env:DESKTOP_DIR;" ^
  "$Shortcut.IconLocation = $env:LOCAL_ICON;" ^
  "$Shortcut.Save()"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to create the desktop shortcut.
    echo.
    pause
    exit /b 1
)

echo Success.
echo.
echo Shortcut created:
echo   "%DESKTOP_DIR%\%SHORTCUT_NAME%"
echo.
echo It opens:
echo   %URL%
echo.
echo Icon copied to:
echo   "%LOCAL_ICON%"
echo.
pause
exit /b 0
