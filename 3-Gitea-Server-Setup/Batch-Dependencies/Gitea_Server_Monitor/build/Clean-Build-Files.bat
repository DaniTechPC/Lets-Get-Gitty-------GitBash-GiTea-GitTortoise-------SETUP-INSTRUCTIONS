@echo off
setlocal
title Clean Gitea Server Monitor Build Files

echo Cleaning temporary PyInstaller files...

if exist "%~dp0build_temp" rmdir /S /Q "%~dp0build_temp"
if exist "%~dp0__pycache__" rmdir /S /Q "%~dp0__pycache__"
if exist "%~dp0..\code\__pycache__" rmdir /S /Q "%~dp0..\code\__pycache__"
if exist "%~dp0*.spec" del /Q "%~dp0*.spec"

echo Done.
pause
