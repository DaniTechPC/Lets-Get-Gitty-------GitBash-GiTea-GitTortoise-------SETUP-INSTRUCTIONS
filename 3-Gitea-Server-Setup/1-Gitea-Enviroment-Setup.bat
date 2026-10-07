@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Gitea Server Folder Setup
REM Creates the Gitea folder structure on the drive this BAT
REM file is running from.
REM
REM Example:
REM   C:\Setup-Gitea-Server.bat -> C:\Gitea\
REM   D:\Setup-Gitea-Server.bat -> D:\Gitea\
REM ============================================================

set "TARGET_DRIVE=%~d0"
set "GITEA_ROOT=%TARGET_DRIVE%\Gitea"
set "MONITOR_SOURCE=%~dp0Batch-Dependencies\Gitea_Server_Monitor"
set "MONITOR_DEST=%GITEA_ROOT%\Gitea_Server_Monitor"

cls
echo ============================================================
echo                 Gitea Server Folder Setup
echo ============================================================
echo.
echo Target drive:
echo   %TARGET_DRIVE%
echo.
echo Gitea directory:
echo   %GITEA_ROOT%
echo.

REM ------------------------------------------------------------
REM Creating a folder in the root of C: may require Administrator
REM privileges. Check whether the target folder can be created.
REM ------------------------------------------------------------

if not exist "%GITEA_ROOT%" (
    mkdir "%GITEA_ROOT%" >nul 2>&1
)

if not exist "%GITEA_ROOT%" (
    echo Administrator permission is required.
    echo Requesting elevation...
    echo.

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"

    exit /b
)

echo Creating/verifying Gitea folder structure...
echo.

call :CreateFolder "%GITEA_ROOT%\data"
call :CreateFolder "%GITEA_ROOT%\lfs"
call :CreateFolder "%GITEA_ROOT%\logs"
call :CreateFolder "%GITEA_ROOT%\repositories"
call :CreateFolder "%MONITOR_DEST%"

echo.
echo Copying Gitea Server Monitor files...

if not exist "%MONITOR_SOURCE%\" (
    echo.
    echo   [ERROR] Source folder was not found:
    echo           %MONITOR_SOURCE%
    echo.
    echo Keep "Gitea_Server_Monitor" inside the "Batch-Dependencies" folder beside this BAT.
    echo The destination folder was created, but no monitor files were copied.
    echo.
) else (
    robocopy "%MONITOR_SOURCE%" "%MONITOR_DEST%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul
    set "ROBOCOPY_EXIT=!ERRORLEVEL!"

    if !ROBOCOPY_EXIT! LEQ 7 (
        echo   [OK] Gitea Server Monitor files copied to:
        echo        %MONITOR_DEST%
    ) else (
        echo   [ERROR] Robocopy failed with exit code !ROBOCOPY_EXIT!.
        echo           Source: %MONITOR_SOURCE%
        echo           Destination: %MONITOR_DEST%
    )
)

echo.
echo ============================================================
echo Setup complete.
echo ============================================================
echo.
echo Folder structure:
echo.
echo   %GITEA_ROOT%\
echo       data\
echo       lfs\
echo       logs\
echo       repositories\
echo       Gitea_Server_Monitor\
echo.
pause
exit /b 0


:CreateFolder
if exist "%~1" (
    echo   [OK] Existing: %~1
) else (
    mkdir "%~1" >nul 2>&1
    if exist "%~1" (
        echo   [OK] Created:  %~1
    ) else (
        echo   [ERROR] Could not create: %~1
    )
)
exit /b 0
