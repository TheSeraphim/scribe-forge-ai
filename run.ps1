<#
.SYNOPSIS
    Scribe Forge AI - Run Script
.DESCRIPTION
    Activates the virtual environment and runs the transcription application
.PARAMETER Arguments
    All arguments are passed directly to main.py
.EXAMPLE
    .\run.ps1 audio.mp3 --diarize --language it
#>

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $PSCommandPath
$venvActivate = Join-Path $ScriptRoot ".venv\Scripts\Activate.ps1"

# Check if virtual environment exists
if (-not (Test-Path $venvActivate)) {
    Write-Host "❌ Virtual environment not found!" -ForegroundColor Red
    Write-Host "Please run install.ps1 first to set up the environment." -ForegroundColor Yellow
    exit 1
}

# Activate virtual environment
try {
    . $venvActivate
    Write-Host "✅ Virtual environment activated" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to activate virtual environment: $_" -ForegroundColor Red
    exit 1
}

# Run main.py with all passed arguments
$mainScript = Join-Path $ScriptRoot "main.py"
python $mainScript @Arguments

# Preserve exit code
exit $LASTEXITCODE