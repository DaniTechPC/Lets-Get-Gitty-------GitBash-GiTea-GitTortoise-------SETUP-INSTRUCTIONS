@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM Gitea Post-Setup Settings
REM
REM Updates:
REM   [repository.upload]
REM   ENABLED = true
REM   MAX_FILES = 100
REM   FILE_MAX_SIZE = 100
REM   ALLOWED_TYPES = */*
REM
REM   [repository]
REM   DEFAULT_BRANCH = master
REM
REM Target:
REM   <current drive>:\Gitea\custom\conf\app.ini
REM ============================================================

set "TARGET_DRIVE=%~d0"
set "APPINI=%TARGET_DRIVE%\Gitea\custom\conf\app.ini"
set "SELF=%~f0"

cls
echo ============================================================
echo                 Gitea Post-Setup Settings
echo ============================================================
echo.
echo Target configuration:
echo   %APPINI%
echo.

if not exist "%APPINI%" (
    echo ERROR: app.ini was not found.
    echo.
    echo Expected:
    echo   %APPINI%
    echo.
    echo Finish the Gitea web setup first so app.ini is created,
    echo then run this BAT again.
    echo.
    pause
    exit /b 1
)

REM Request admin rights if needed.
net session >nul 2>&1
if errorlevel 1 (
    echo Administrator permission is required.
    echo Requesting elevation...
    echo.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath $env:SELF -Verb RunAs"
    exit /b
)

echo Checking existing Gitea settings...
echo.

REM Run the PowerShell payload stored below this marker.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$raw=Get-Content -Raw -LiteralPath $env:SELF; $marker='#'+' POWERSHELL_PAYLOAD'; $pos=$raw.IndexOf($marker); if($pos -lt 0){Write-Host 'ERROR: Internal setup payload was not found.'; exit 99}; $code=$raw.Substring($pos+$marker.Length); Invoke-Expression $code"

set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo ============================================================
    echo Settings verified successfully.
    echo ============================================================
    echo.
    echo Gitea configuration now uses:
    echo.
    echo   [repository.upload]
    echo   ENABLED = true
    echo   MAX_FILES = 100
    echo   FILE_MAX_SIZE = 100
    echo   ALLOWED_TYPES = */*
    echo.
    echo   [repository]
    echo   DEFAULT_BRANCH = master
    echo.
    echo IMPORTANT: Restart Gitea for app.ini changes to take effect.
    echo.
) else (
    echo ============================================================
    echo ERROR: Gitea settings could not be updated.
    echo ============================================================
    echo.
)

pause
exit /b %RC%


# POWERSHELL_PAYLOAD

$ErrorActionPreference = 'Stop'
$path = $env:APPINI

function Update-IniSection {
    param(
        [string[]]$InputLines,
        [string]$SectionName,
        [hashtable]$DesiredValues,
        [string[]]$KeyOrder
    )

    $header = "[$SectionName]"
    $start = -1

    for ($i = 0; $i -lt $InputLines.Count; $i++) {
        if ($InputLines[$i].Trim() -ieq $header) {
            $start = $i
            break
        }
    }

    # Section does not exist: append it.
    if ($start -lt 0) {
        $result = @($InputLines)

        if ($result.Count -gt 0 -and $result[$result.Count - 1].Trim() -ne '') {
            $result += ''
        }

        $result += $header

        foreach ($key in $KeyOrder) {
            $result += "$key = $($DesiredValues[$key])"
        }

        return ,$result
    }

    # Locate the next INI section.
    $end = $InputLines.Count
    for ($i = $start + 1; $i -lt $InputLines.Count; $i++) {
        if ($InputLines[$i].Trim() -match '^\[.+\]$') {
            $end = $i
            break
        }
    }

    $before = @()
    if ($start -gt 0) {
        $before = @($InputLines[0..($start - 1)])
    }

    $body = @()
    if ($end -gt ($start + 1)) {
        $body = @($InputLines[($start + 1)..($end - 1)])
    }

    $after = @()
    if ($end -lt $InputLines.Count) {
        $after = @($InputLines[$end..($InputLines.Count - 1)])
    }

    $newBody = @()
    $seen = @{}

    foreach ($line in $body) {
        $matchedDesiredKey = $false

        foreach ($key in $KeyOrder) {
            $pattern = '^\s*' + [regex]::Escape($key) + '\s*='

            if ($line -match $pattern) {
                $matchedDesiredKey = $true

                if (-not $seen.ContainsKey($key)) {
                    $newBody += "$key = $($DesiredValues[$key])"
                    $seen[$key] = $true
                }

                # Additional duplicates are intentionally skipped.
                break
            }
        }

        if (-not $matchedDesiredKey) {
            $newBody += $line
        }
    }

    # Add any missing desired keys.
    foreach ($key in $KeyOrder) {
        if (-not $seen.ContainsKey($key)) {
            $newBody += "$key = $($DesiredValues[$key])"
        }
    }

    $result = @()
    $result += $before
    $result += $header
    $result += $newBody
    $result += $after

    return ,$result
}

try {
    $original = [System.IO.File]::ReadAllLines($path)
    $lines = @($original)

    $uploadValues = @{
        'ENABLED'       = 'true'
        'MAX_FILES'     = '100'
        'FILE_MAX_SIZE' = '100'
        'ALLOWED_TYPES' = '*/*'
    }

    $repositoryValues = @{
        'DEFAULT_BRANCH' = 'master'
    }

    $lines = Update-IniSection `
        -InputLines $lines `
        -SectionName 'repository.upload' `
        -DesiredValues $uploadValues `
        -KeyOrder @('ENABLED','MAX_FILES','FILE_MAX_SIZE','ALLOWED_TYPES')

    $lines = Update-IniSection `
        -InputLines $lines `
        -SectionName 'repository' `
        -DesiredValues $repositoryValues `
        -KeyOrder @('DEFAULT_BRANCH')

    $originalText = [string]::Join("`n", $original)
    $newText = [string]::Join("`n", $lines)

    if ($originalText -eq $newText) {
        Write-Host '  [OK] All requested settings are already present and correct.'
        exit 0
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$path.backup-$stamp"
    Copy-Item -LiteralPath $path -Destination $backup -Force

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($path, [string[]]$lines, $utf8NoBom)

    Write-Host '  [OK] app.ini updated.'
    Write-Host "  [OK] Backup created: $backup"
    exit 0
}
catch {
    Write-Host "  [ERROR] $($_.Exception.Message)"
    exit 2
}
