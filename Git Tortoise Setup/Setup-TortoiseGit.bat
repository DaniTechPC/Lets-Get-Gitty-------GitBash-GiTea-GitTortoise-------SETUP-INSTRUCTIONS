@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title TortoiseGit Setup

set "DEPENDENCY_DIR=%~dp0Batch-Dependencies"
set "SETTINGS_FILE=%DEPENDENCY_DIR%\TortoiseGit_Settings.reg"

cls
echo ============================================================
echo                    TortoiseGit Setup
echo ============================================================
echo.
echo This setup will:
echo   1. Import the standard TortoiseGit settings.
echo   2. Configure your Git Name and Email.
echo   3. Optionally enable the Windows Classic Menu.
echo.

rem ------------------------------------------------------------
rem Verify dependency file
rem ------------------------------------------------------------
if not exist "%SETTINGS_FILE%" (
    echo [ERROR] Required settings file was not found:
    echo         "%SETTINGS_FILE%"
    echo.
    echo Keep this batch file next to the Batch-Dependencies folder.
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Verify Git is installed and available
rem ------------------------------------------------------------
where git.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git was not found in PATH.
    echo.
    echo Please install Git for Windows first, then run this setup again.
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Ask for Git identity
rem ------------------------------------------------------------
:AskName
set "GIT_NAME="
set /p "GIT_NAME=Name: "
if not defined GIT_NAME (
    echo Name cannot be blank.
    echo.
    goto AskName
)

echo.

:AskEmail
set "GIT_EMAIL="
set /p "GIT_EMAIL=Email: "
if not defined GIT_EMAIL (
    echo Email cannot be blank.
    echo.
    goto AskEmail
)

echo.
echo ------------------------------------------------------------
echo Importing TortoiseGit settings...
echo ------------------------------------------------------------
reg.exe import "%SETTINGS_FILE%" >nul
if errorlevel 1 (
    echo [ERROR] TortoiseGit settings could not be imported.
    echo.
    pause
    exit /b 1
)
echo [OK] TortoiseGit settings imported.

rem ------------------------------------------------------------
rem Set global Git identity used by Git and TortoiseGit
rem ------------------------------------------------------------
echo.
echo Configuring Git identity...
git.exe config --global user.name "%GIT_NAME%"
if errorlevel 1 (
    echo [ERROR] Could not save Git user.name.
    echo.
    pause
    exit /b 1
)

git.exe config --global user.email "%GIT_EMAIL%"
if errorlevel 1 (
    echo [ERROR] Could not save Git user.email.
    echo.
    pause
    exit /b 1
)

echo [OK] Name:  %GIT_NAME%
echo [OK] Email: %GIT_EMAIL%

rem ------------------------------------------------------------
rem Optional Windows Classic Menu
rem ------------------------------------------------------------
echo.
echo ------------------------------------------------------------
echo Would you like to enable "Windows Classic Menu" (Highly Recommended)?
echo Note: Can be reversed by running "un-Classic-Windows-Menu.bat"
echo       located in Batch-Dependencies folder.
echo ------------------------------------------------------------
choice /C YN /N /M "Enter Y or N: "
if errorlevel 2 goto SkipClassicMenu

:EnableClassicMenu
echo.
echo Enabling Windows Classic Menu...
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve >nul
if errorlevel 1 (
    echo [WARNING] Windows Classic Menu could not be enabled.
) else (
    echo [OK] Windows Classic Menu enabled.
    echo      It may require restarting Windows Explorer or signing out
    echo      before the change appears.
)
goto Finish

:SkipClassicMenu
echo.
echo [SKIPPED] Windows Classic Menu was not enabled.

:Finish
echo.
echo ============================================================
echo                     Setup Complete
echo ============================================================
echo.
echo TortoiseGit settings have been imported.
echo Git Name:  %GIT_NAME%
echo Git Email: %GIT_EMAIL%
echo.
echo You can verify the Git identity with:
echo   git config --global user.name
echo   git config --global user.email
echo.
pause
endlocal
exit /b 0
