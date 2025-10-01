<#
.SYNOPSIS
    Scribe Forge AI - Run Script
.DESCRIPTION
    Activates the virtual environment and runs the transcription application.
    All arguments are passed directly to main.py exactly as provided.
.PARAMETER Arguments
    All arguments are passed through to main.py without modification
.EXAMPLE
    .\run.ps1 audio.mp3 -o output --format txt
    .\run.ps1 audio.mp3 --diarize --language it -o transcripts/output
    .\run.ps1 "my file.mp3" -o "My Documents/output" --format md
    .\run.ps1 --help
.NOTES
    Requires virtual environment to be created first (run install.ps1)
#>

param(
    # Pass-through args to main.py (kept for compatibility/tests)
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments,

    # Friendly PowerShell flags mapped to main.py CLI
    [string]$Input,
    [switch]$Diarize,
    [switch]$DownloadModels,
    [string]$ModelSize,
    [string]$Format,
    [string]$Language,
    [ValidateSet('auto','cpu','cuda')]
    [string]$Device,
    [string]$Output,
    [switch]$CleanAudio,
    [switch]$AssumeYes,
    [switch]$CreateOutputDir
)

$ErrorActionPreference = "Stop"

# Determine script root directory (works in all PowerShell execution contexts)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    try { $ScriptRoot = Split-Path -Parent $PSCommandPath } catch {}
}
if (-not $ScriptRoot) {
    try { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {}
}
if (-not $ScriptRoot) {
    $ScriptRoot = (Get-Location).Path
}

$venvActivate = Join-Path $ScriptRoot ".venv\Scripts\Activate.ps1"
$mainScript = Join-Path $ScriptRoot "main.py"

# Validate required files exist
if (-not (Test-Path $venvActivate)) {
    Write-Host "ERROR: Virtual environment not found at: $venvActivate" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run install.ps1 first to set up the environment:" -ForegroundColor Yellow
    Write-Host "  .\install.ps1" -ForegroundColor Cyan
    exit 1
}

if (-not (Test-Path $mainScript)) {
    Write-Host "ERROR: main.py not found at: $mainScript" -ForegroundColor Red
    exit 1
}

# Activate virtual environment (suppress activation output)
try {
    & $venvActivate
    if ($LASTEXITCODE -ne 0) {
        throw "Activation script exited with code $LASTEXITCODE"
    }
} catch {
    Write-Host "ERROR: Failed to activate virtual environment: $_" -ForegroundColor Red
    exit 1
}

# Validate Python is available in venv
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "ERROR: Python not available after venv activation" -ForegroundColor Red
    exit 1
}

# Build args list: mapped flags first, then passthrough
$argsList = @()
if ($Input) { $argsList += $Input }
if ($Diarize) { $argsList += "--diarize" }
if ($DownloadModels) { $argsList += "--download-models" }
if ($CleanAudio) { $argsList += "--clean-audio" }
if ($AssumeYes) { $argsList += "--assume-yes" }
if ($CreateOutputDir) { $argsList += "--create-output-dir" }
if ($ModelSize) { $argsList += @("--model-size", $ModelSize) }
if ($Format) { $argsList += @("--format", $Format) }
if ($Language) { $argsList += @("--language", $Language) }
if ($Device) { $argsList += @("--device", $Device) }
if ($Output) { $argsList += @("-o", $Output) }
if ($Arguments) { $argsList += $Arguments }

# Run main.py using the assembled argument array
& python $mainScript @argsList

# Capture and preserve the exit code from main.py
$exitCode = $LASTEXITCODE

# Exit with the same code that main.py returned
exit $exitCode
