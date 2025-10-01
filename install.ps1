param(
    [switch]$SkipDependencies,
    [switch]$NoGPU,
    [switch]$DownloadModels,
    [switch]$DownloadDiarizationModels,
    [switch]$SkipDiarization,
    [switch]$ForceNonAdmin,
    [string]$HuggingFaceToken,
    [switch]$NoSmoke,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    try { $ScriptRoot = Split-Path -Parent $PSCommandPath } catch {}
}
if (-not $ScriptRoot) {
    try { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {}
}
if (-not $ScriptRoot) { $ScriptRoot = (Get-Location).Path }

function Write-ColorOutput {
    param([string]$Message,[ConsoleColor]$Color=[ConsoleColor]::White)
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $prev
}

function Show-Help {
    Write-Host "USAGE: .\install.ps1 [options]"
    Write-Host "-SkipDependencies                 Skip system dependency installation"
    Write-Host "-NoGPU                            Force CPU-only PyTorch installation"
    Write-Host "-DownloadModels                   Download and warm up base Whisper models"
    Write-Host "-DownloadDiarizationModels        Download diarization models (pyannote)"
    Write-Host "-SkipDiarization                  Skip diarization setup"
    Write-Host "-ForceNonAdmin                    Allow running without Administrator privileges"
    Write-Host "-HuggingFaceToken <token>         HuggingFace token for pyannote.audio"
    Write-Host "-NoSmoke                          Disable quick smoke tests"
    Write-Host "-Help                             Show this help"
}

if ($Help) { Show-Help; exit 0 }

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-PythonScript {
    param([Parameter(Mandatory=$true)][string]$Code,[switch]$IgnoreExitCode)
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $Code -Encoding UTF8
    & python $tmp
    $rc = $LASTEXITCODE
    Remove-Item $tmp -Force
    if (-not $IgnoreExitCode -and $rc -ne 0) { throw "Python exited with code $rc" }
    return $rc
}

function Resolve-Python {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $ver = & python -c "import sys;print(sys.version.split()[0])"
    [pscustomobject]@{ exe = $cmd.Source; ver = $ver }
}

function Ensure-Venv {
    $venvPath = Join-Path $ScriptRoot ".venv"
    if (-not (Test-Path $venvPath)) { & python -m venv "$venvPath" }
    $activate = Join-Path $venvPath "Scripts\Activate.ps1"
    . $activate
    & python -m pip install --upgrade pip wheel setuptools
}

function Install-PyTorch {
    if ($NoGPU) {
        Write-ColorOutput "Installing PyTorch (CPU-only)" ([ConsoleColor]::Yellow)
        & python -m pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        return
    }
    $hasNvidia = $false
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        try { & nvidia-smi | Out-Null; $hasNvidia = $LASTEXITCODE -eq 0 } catch { $hasNvidia = $false }
    }
    if ($hasNvidia) {
        Write-ColorOutput "NVIDIA GPU detected: installing CUDA build" ([ConsoleColor]::Green)
        try {
            & python -m pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
        } catch {
            Write-ColorOutput "Falling back to CPU-only build" ([ConsoleColor]::Yellow)
            & python -m pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        }
    } else {
        Write-ColorOutput "No GPU detected: installing CPU-only build" ([ConsoleColor]::Yellow)
        & python -m pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    }
}

function Install-ProjectRequirements {
    $req = Join-Path $ScriptRoot "requirements.txt"
    if (Test-Path -Path $req) {
        Write-ColorOutput "Installing requirements.txt" ([ConsoleColor]::Yellow)
        & python -m pip install -r $req
    }
}

function Install-WhisperAndModels {
    $needWhisper = Invoke-PythonScript -Code 'import importlib,sys;sys.exit(0 if importlib.util.find_spec("whisper") else 1)' -IgnoreExitCode
    if ($needWhisper -ne 0) {
        Write-ColorOutput "Installing openai-whisper" ([ConsoleColor]::Yellow)
        & python -m pip install openai-whisper
    }
    if ($DownloadModels) {
        Write-ColorOutput "Warming up Whisper base model" ([ConsoleColor]::Yellow)
        Invoke-PythonScript -Code 'import whisper; whisper.load_model("base")'
    }
}

function Install-Diarization {
    if ($SkipDiarization) { return }
    Write-ColorOutput "Installing pyannote.audio" ([ConsoleColor]::Yellow)
    & python -m pip install "pyannote.audio>=3.0"
    if ($HuggingFaceToken) { $env:HUGGING_FACE_HUB_TOKEN = $HuggingFaceToken }
    if ($DownloadDiarizationModels -or $HuggingFaceToken) {
        Invoke-PythonScript -Code @'
import os
try:
    from huggingface_hub import login
    tok = os.environ.get("HUGGING_FACE_HUB_TOKEN")
    if tok:
        login(token=tok, add_to_git_credential=False)
except Exception:
    pass
'@
    }
}

function Run-Smoke {
    if ($NoSmoke) {
        Write-ColorOutput "Smoke tests disabled (--NoSmoke)" ([ConsoleColor]::Yellow)
        return
    }
    Write-ColorOutput "Running smoke tests" ([ConsoleColor]::Yellow)
    Invoke-PythonScript -Code @'
import importlib, sys
ok = True
try:
    import torch
    _ = torch.cuda.is_available()
except Exception:
    ok = False
try:
    m = None
    for name in ("whisper","faster_whisper"):
        if importlib.util.find_spec(name):
            m = name
            break
    if m is None:
        ok = False
except Exception:
    ok = False
print("OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
'@
}

function Main {
    if (-not $ForceNonAdmin -and -not (Test-IsAdmin)) {
        Write-ColorOutput "Run PowerShell as Administrator or pass -ForceNonAdmin" ([ConsoleColor]::Red)
        exit 1
    }
    $py = Resolve-Python
    if (-not $py) {
        Write-ColorOutput "Python not found in PATH" ([ConsoleColor]::Red)
        exit 1
    }
    Ensure-Venv
    if (-not $SkipDependencies) { Install-PyTorch }
    Install-ProjectRequirements
    Install-WhisperAndModels
    Install-Diarization
    Run-Smoke
    Write-ColorOutput "Installation completed" ([ConsoleColor]::Green)
}

Main
