@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Disable Windows Classic Menu

cls
echo ============================================================
echo              Disable Windows Classic Menu
echo ============================================================
echo.
echo Reverting the Windows Classic Menu setting...
echo.

reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f >nul
if errorlevel 1 (
    echo [WARNING] The Classic Menu registry setting was not found,
    echo           or it could not be removed.
) else (
    echo [OK] Windows Classic Menu has been disabled.
    echo.
    echo The change may require restarting Windows Explorer or
    echo signing out and back in before it appears.
)

echo.
pause
endlocal
exit /b 0
