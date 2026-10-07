@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM Gitea Help Banner Setup
REM
REM Creates/updates:
REM   <current drive>:\Gitea\custom\templates\custom\extra_links.tmpl
REM   <current drive>:\Gitea\custom\templates\custom\body_inner_pre.tmpl
REM
REM The repository owner username is entered by the user.
REM ============================================================

set "TARGET_DRIVE=%~d0"
set "TEMPLATE_DIR=%TARGET_DRIVE%\Gitea\custom\templates\custom"
set "EXTRA_LINKS=%TEMPLATE_DIR%\extra_links.tmpl"
set "BODY_PRE=%TEMPLATE_DIR%\body_inner_pre.tmpl"
set "SELF=%~f0"

cls
echo ============================================================
echo                  Gitea Help Banner Setup
echo ============================================================
echo.
echo Target folder:
echo   %TEMPLATE_DIR%
echo.
echo A Gitea username is REQUIRED.
echo No default username will be used.
echo.

REM ------------------------------------------------------------
REM Request administrator rights if needed.
REM ------------------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo Administrator permission may be required.
    echo Requesting elevation...
    echo.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath $env:SELF -Verb RunAs"
    exit /b
)

REM ------------------------------------------------------------
REM Ask for the Gitea repository owner username.
REM ------------------------------------------------------------
:ASK_OWNER
set "GITEA_OWNER="
set /p "GITEA_OWNER=Enter the REQUIRED Gitea username that owns Gitea-Help-Documents: "

if not defined GITEA_OWNER (
    echo.
    echo ERROR: A username is required. No default username will be used.
    echo.
    goto :ASK_OWNER
)

echo.
echo Repository link will be:
echo   {{AppSubUrl}}/%GITEA_OWNER%/Gitea-Help-Documents
echo.

REM ------------------------------------------------------------
REM Create template directory if it does not already exist.
REM ------------------------------------------------------------
if not exist "%TEMPLATE_DIR%" (
    mkdir "%TEMPLATE_DIR%" >nul 2>&1
)

if not exist "%TEMPLATE_DIR%" (
    echo ERROR: Could not create:
    echo   %TEMPLATE_DIR%
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Back up existing template files before replacing them.
REM ------------------------------------------------------------
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%T"
if not defined STAMP set "STAMP=backup"

if exist "%EXTRA_LINKS%" (
    copy /y "%EXTRA_LINKS%" "%EXTRA_LINKS%.backup-%STAMP%" >nul
    echo [BACKUP] extra_links.tmpl
)

if exist "%BODY_PRE%" (
    copy /y "%BODY_PRE%" "%BODY_PRE%.backup-%STAMP%" >nul
    echo [BACKUP] body_inner_pre.tmpl
)

REM ------------------------------------------------------------
REM Write extra_links.tmpl
REM Use normal BAT output instead of inline PowerShell so HTML
REM quotation marks are preserved exactly.
REM ------------------------------------------------------------
(
    echo ^<a class="item" href="{{AppSubUrl}}/%GITEA_OWNER%/Gitea-Help-Documents"^>
    echo   Help / Getting Started
    echo ^</a^>
) > "%EXTRA_LINKS%"

if errorlevel 1 (
    echo.
    echo ERROR: Could not create extra_links.tmpl
    echo.
    pause
    exit /b 2
)

REM ------------------------------------------------------------
REM Write body_inner_pre.tmpl
REM ------------------------------------------------------------
(
    echo ^<div class="ui info message" style="margin: 0; border-radius: 0; text-align: center;"^>
    echo   ^<strong^>New to Gitea Version Control?^</strong^>
    echo   ^<a href="{{AppSubUrl}}/%GITEA_OWNER%/Gitea-Help-Documents"^>
    echo     Open the Getting Started Wiki
    echo   ^</a^>
    echo ^</div^>
) > "%BODY_PRE%"

if errorlevel 1 (
    echo.
    echo ERROR: Could not create body_inner_pre.tmpl
    echo.
    pause
    exit /b 3
)

echo.
echo ============================================================
echo Help Banner templates created successfully.
echo ============================================================
echo.
echo Repository owner:
echo   %GITEA_OWNER%
echo.
echo Created:
echo   %EXTRA_LINKS%
echo   %BODY_PRE%
echo.
echo IMPORTANT: Restart Gitea for the template changes to appear.
echo.
pause
exit /b 0
