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
# Check if venv is already active
$venvAlreadyActive = $false
if ($env:VIRTUAL_ENV) {
    $currentVenv = [System.IO.Path]::GetFullPath($env:VIRTUAL_ENV)
    $expectedVenv = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot ".venv"))
    if ($currentVenv -eq $expectedVenv) {
        $venvAlreadyActive = $true
        Write-Host "[run] Virtual environment already active" -ForegroundColor DarkGray
    } else {
        Write-Host "WARNING: Different venv is active: $currentVenv" -ForegroundColor Yellow
        Write-Host "Expected: $expectedVenv" -ForegroundColor Yellow
        Write-Host "Please deactivate first, then run this script again." -ForegroundColor Yellow
        exit 1
    }
}

if (-not $venvAlreadyActive) {
    try {
        & $venvActivate
        if ($LASTEXITCODE -ne 0) {
            throw "Activation script exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Host "ERROR: Failed to activate virtual environment: $_" -ForegroundColor Red
        exit 1
    }
}

# Validate Python is available in venv
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "ERROR: Python not available after venv activation" -ForegroundColor Red
    exit 1
}

# Build args list in required order: Input, passthrough, then mapped flags
$argsList = @()

# Positional input first if provided via -Input
if ($Input) { $argsList += $Input }

# Preserve raw pass-through next
if ($Arguments) { $argsList += $Arguments }

# Then append mapped flags
if ($Output) { $argsList += @("-o", $Output) }
if ($Format) { $argsList += @("--format", $Format) }
if ($ModelSize) { $argsList += @("--model-size", $ModelSize) }
if ($Device) { $argsList += @("--device", $Device) }
if ($Diarize) { $argsList += "--diarize" }
if ($DownloadModels) { $argsList += "--download-models" }
if ($CleanAudio) { $argsList += "--clean-audio" }
if ($AssumeYes) { $argsList += "--assume-yes" }
if ($CreateOutputDir) { $argsList += "--create-output-dir" }
if ($Language) { $argsList += @("--language", $Language) }

# Fail fast if no positional input was provided
if (-not ($argsList | Where-Object { $_ -notmatch '^-'})) {
  Write-Host "ERROR: missing input_file"
  exit 2
}

# Optional device availability hint (non-blocking, non-fatal)
Write-Host "[run] hint: probing CUDA availability..." -ForegroundColor DarkGray
try {
    $pythonCode = @'
try:
    import torch
    print('HINT torch_cuda_is_available=', bool(torch.cuda.is_available()))
except Exception:
    print('HINT torch_unavailable')
'@
    $null = & python -c $pythonCode 2>$null
} catch {
    # Silently ignore any errors
}

# Run main.py using the assembled argument array
& python $mainScript @argsList

# Capture and preserve the exit code from main.py
$exitCode = $LASTEXITCODE

# Exit with the same code that main.py returned
exit $exitCode
