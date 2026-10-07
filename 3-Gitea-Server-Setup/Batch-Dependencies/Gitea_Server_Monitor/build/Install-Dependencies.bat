@echo off
setlocal EnableExtensions
title Install Gitea Monitor Dependencies

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
    echo Python was not found.
    pause
    exit /b 1
)

%PYTHON_CMD% -m pip install --user -r "%~dp0requirements.txt"
pause
