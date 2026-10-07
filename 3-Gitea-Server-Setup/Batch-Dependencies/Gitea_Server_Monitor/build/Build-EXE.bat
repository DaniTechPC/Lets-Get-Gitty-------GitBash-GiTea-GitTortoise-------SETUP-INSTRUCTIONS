@echo off
setlocal EnableExtensions
title Build EXE - Gitea Server Monitor

set "PYTHON_CMD="

where py >nul 2>nul
if not errorlevel 1 set "PYTHON_CMD=py"

if not defined PYTHON_CMD (
    where python >nul 2>nul
    if not errorlevel 1 set "PYTHON_CMD=python"
)

if not defined PYTHON_CMD (
    where python3 >nul 2>nul
    if not errorlevel 1 set "PYTHON_CMD=python3"
)

if not defined PYTHON_CMD (
    echo Python was not found by this build script.
    echo.
    echo Try this in Command Prompt:
    echo     where python
    echo     python --version
    echo.
    pause
    exit /b 1
)

echo Using Python command: %PYTHON_CMD%
%PYTHON_CMD% --version
echo.

echo Installing/updating build dependencies...
%PYTHON_CMD% -m pip install --user -r "%~dp0requirements.txt"
if errorlevel 1 (
    echo.
    echo Dependency installation failed.
    pause
    exit /b 1
)

if not exist "%~dp0..\code\GiteaServerMonitor.pyw" (
    echo.
    echo Missing source code file:
    echo "%~dp0..\code\GiteaServerMonitor.pyw"
    pause
    exit /b 1
)

echo.
echo Building GiteaServerMonitor.exe...
%PYTHON_CMD% -m PyInstaller ^
  --noconfirm ^
  --clean ^
  --onefile ^
  --windowed ^
  --icon "%~dp0GiteaServerMonitor.ico" ^
  --add-data "%~dp0GiteaServerMonitor.ico;." ^
  --add-data "%~dp0GiteaServerMonitor_icon.png;." ^
  --distpath "%~dp0dist" ^
  --workpath "%~dp0build_temp" ^
  --specpath "%~dp0build_temp" ^
  --name GiteaServerMonitor ^
  "%~dp0..\code\GiteaServerMonitor.pyw"

if errorlevel 1 (
    echo.
    echo PyInstaller build failed.
    pause
    exit /b 1
)

echo.
echo Build output:
echo "%~dp0dist\GiteaServerMonitor.exe"
echo.
exit /b 0
