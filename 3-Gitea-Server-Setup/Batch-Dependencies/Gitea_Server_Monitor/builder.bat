@echo off
setlocal EnableExtensions
title Build Gitea Server Monitor

echo.
echo ==========================================
echo   Gitea Server Monitor Builder
echo ==========================================
echo.

cd /d "%~dp0build"
if errorlevel 1 (
    echo Could not enter the build folder.
    pause
    exit /b 1
)

call "%~dp0build\Build-EXE.bat"
if errorlevel 1 (
    echo.
    echo Build failed. The main EXE was not updated.
    pause
    exit /b 1
)

if not exist "%~dp0build\dist\GiteaServerMonitor.exe" (
    echo.
    echo Build completed, but the EXE was not found:
    echo "%~dp0build\dist\GiteaServerMonitor.exe"
    pause
    exit /b 1
)

copy /Y "%~dp0build\dist\GiteaServerMonitor.exe" "%~dp0GiteaServerMonitor.exe" >nul
if errorlevel 1 (
    echo.
    echo Could not copy the EXE to the main folder.
    pause
    exit /b 1
)

echo.
echo Creating desktop shortcut: Server Monitor
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$exe='%~dp0GiteaServerMonitor.exe';" ^
  "$desktop=[Environment]::GetFolderPath('Desktop');" ^
  "$shortcutPath=Join-Path $desktop 'Server Monitor.lnk';" ^
  "$shell=New-Object -ComObject WScript.Shell;" ^
  "$shortcut=$shell.CreateShortcut($shortcutPath);" ^
  "$shortcut.TargetPath=$exe;" ^
  "$shortcut.WorkingDirectory='%~dp0';" ^
  "$shortcut.IconLocation=$exe + ',0';" ^
  "$shortcut.Description='Gitea Server Monitor';" ^
  "$shortcut.Save()"

if errorlevel 1 (
    echo.
    echo Build completed, but the desktop shortcut could not be created.
    echo You can still run:
    echo "%~dp0GiteaServerMonitor.exe"
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   Build Complete
echo ==========================================
echo.
echo Main EXE created here:
echo "%~dp0GiteaServerMonitor.exe"
echo.
echo Desktop shortcut created:
echo "%USERPROFILE%\Desktop\Server Monitor.lnk"
echo.
echo PyInstaller output remains here:
echo "%~dp0build\dist\GiteaServerMonitor.exe"
echo.
pause
