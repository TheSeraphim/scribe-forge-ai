param(
    [switch]$SkipDependencies,
    [switch]$NoGPU,
    [switch]$DownloadModels,
    [switch]$DownloadDiarizationModels,
    [switch]$SkipDiarization,
    [switch]$ForceNonAdmin,
    [string]$HuggingFaceToken = "",
    [string]$GitHubToken = "",
    [switch]$AssumeYes,
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
    Write-Host "-HuggingFaceToken <token>         Hugging Face token for pyannote.audio"
    Write-Host "-GitHubToken <token>              GitHub token (optional; for gh auth)"
    Write-Host "-AssumeYes                        Reserved (non-interactive; no prompts)"
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
    $torch = "torch==2.6.0"; $vision = "torchvision==0.21.0"; $audio = "torchaudio==2.6.0"
    if ($NoGPU) {
        Write-ColorOutput "Installing PyTorch (CPU-only pinned)" ([ConsoleColor]::Yellow)
        & python -m pip install --index-url https://download.pytorch.org/whl/cpu $torch $vision $audio
        return
    }
    $hasNvidia = $false
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        try { & nvidia-smi | Out-Null; $hasNvidia = $LASTEXITCODE -eq 0 } catch { $hasNvidia = $false }
    }
    if ($hasNvidia) {
        Write-ColorOutput "NVIDIA GPU detected: installing CUDA 12.4 pinned build" ([ConsoleColor]::Green)
        try {
            & python -m pip install --index-url https://download.pytorch.org/whl/cu124 $torch $vision $audio
        } catch {
            Write-ColorOutput "Falling back to CPU-only pinned build" ([ConsoleColor]::Yellow)
            & python -m pip install --index-url https://download.pytorch.org/whl/cpu $torch $vision $audio
        }
    } else {
        Write-ColorOutput "No GPU detected: installing CPU-only pinned build" ([ConsoleColor]::Yellow)
        & python -m pip install --index-url https://download.pytorch.org/whl/cpu $torch $vision $audio
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
    Write-ColorOutput "Installing Resemblyzer (default diarization backend)" ([ConsoleColor]::Yellow)
    & python -m pip install resemblyzer scikit-learn

    $py_ver = Invoke-PythonScript -Code 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")' -IgnoreExitCode
    $can_pyannote = $false
    $hfTok = $env:HF_TOKEN; if (-not $hfTok) { $hfTok = $env:HUGGINGFACE_HUB_TOKEN }; if (-not $hfTok) { $hfTok = $env:HUGGING_FACE_HUB_TOKEN }
    try {
        $maj,$min = ($py_ver -split '\.')[0..1]
        if ([int]$maj -lt 3 -or ([int]$maj -eq 3 -and [int]$min -le 11)) { $can_pyannote = $true }
    } catch { $can_pyannote = $false }

    if ($can_pyannote -and $hfTok) {
        Write-ColorOutput "Installing pyannote.audio (Python <= 3.11 and HF token present)" ([ConsoleColor]::Yellow)
        & python -m pip install "pyannote.audio>=3.0"
        if ($DownloadDiarizationModels) {
            Invoke-PythonScript -Code @'
import os
try:
    from huggingface_hub import login
    tok = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    if tok:
        login(token=tok, add_to_git_credential=False)
except Exception:
    pass
'@
            try {
                Invoke-PythonScript -Code @'
from pyannote.audio import Pipeline
try:
    Pipeline.from_pretrained("pyannote/speaker-diarization-3.1")
    print("pyannote diarization model cached")
except Exception as e:
    import sys
    print(f"failed to cache diarization model: {e}")
    sys.exit(0)
'@
            } catch {
                Write-ColorOutput "Diarization model pre-download failed; will download on first use." ([ConsoleColor]::Yellow)
            }
        }
    } else {
        Write-ColorOutput "pyannote disabled (python too new or token missing). Using Resemblyzer by default." ([ConsoleColor]::Yellow)
    }
}

function Get-FirstEnv {
    param([string[]]$names)
    foreach ($n in $names) {
        $v = [Environment]::GetEnvironmentVariable($n, 'Process')
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'User') }
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'Machine') }
        if ($v -and $v.Trim() -ne "") { return $v }
    }
    return $null
}

function Run-Smoke {
    if ($NoSmoke) {
        Write-ColorOutput "Smoke tests disabled (--NoSmoke)" ([ConsoleColor]::Yellow)
        return
    }
    Write-ColorOutput "Running smoke tests" ([ConsoleColor]::Yellow)
    Invoke-PythonScript -Code @'
import sys, importlib
ok = True
try:
    import torch
    _ = torch.cuda.is_available()
except Exception:
    ok = False
try:
    import whisper
    whisper.load_model("tiny")
except Exception:
    ok = False
try:
    ok = ok and (importlib.util.find_spec("resemblyzer") is not None)
except Exception:
    ok = False
try:
    import os
    hf = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    allow_pyannote = (sys.version_info[:2] <= (3,11)) and bool(hf)
    if allow_pyannote:
        import pyannote.audio  # noqa: F401
except Exception:
    pass
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
    # Configure tokens early (non-interactive)
    $ResolvedHfToken = if ($HuggingFaceToken) { $HuggingFaceToken } else { Get-FirstEnv @("HF_TOKEN","HUGGINGFACE_HUB_TOKEN","HUGGING_FACE_HUB_TOKEN") }
    $ResolvedGhToken = if ($GitHubToken) { $GitHubToken } else { $env:GITHUB_TOKEN }
    if ($ResolvedHfToken) {
        $env:HF_TOKEN = $ResolvedHfToken
        $env:HUGGINGFACE_HUB_TOKEN = $ResolvedHfToken
        $env:HUGGING_FACE_HUB_TOKEN = $ResolvedHfToken
    }
    if ($ResolvedGhToken) { $env:GITHUB_TOKEN = $ResolvedGhToken }

    if (-not $SkipDependencies) { Install-PyTorch }
    Install-ProjectRequirements
    Install-WhisperAndModels
    Install-Diarization
    Run-Smoke
    Write-ColorOutput "Installation completed" ([ConsoleColor]::Green)
}

Main
