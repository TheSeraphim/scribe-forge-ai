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
    [switch]$Verify,
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
    Write-Host "-Verify                           Optional: run fast repo scan for legacy checks (<=5s)"
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

function Invoke-PythonCapture {
    param([Parameter(Mandatory=$true)][string]$Code)
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $Code -Encoding UTF8
    $output = & python $tmp 2>$null | Out-String
    $rc = $LASTEXITCODE
    Remove-Item $tmp -Force
    return $output.Trim()
}

# Robust, silent CUDA availability check using nvidia-smi
function Test-CudaAvailability {
try {
    $nvsmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvsmi) { return $false }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $nvsmi.Path
    $psi.Arguments = "-L"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $null = $p.StandardOutput.ReadToEnd()
    $null = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
} catch {
    return $false
}
}

function Resolve-Python {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Python non trovato nel PATH. Installa Python 3.9+ e riprova."
}

function Ensure-Venv {
    $python = Resolve-Python
    if (-not $ForceNonAdmin -and -not (Test-IsAdmin)) {
        Write-ColorOutput "È consigliato eseguire come Amministratore per installazioni di sistema." ([ConsoleColor]::Yellow)
    }
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
    $UseCuda = Test-CudaAvailability
    if ($UseCuda) {
        Write-Host "NVIDIA GPU detected: installing CUDA 12.4 pinned build"
        $env:PIP_INDEX_URL = "https://download.pytorch.org/whl/cu124"
        try {
            & python -m pip install --index-url https://download.pytorch.org/whl/cu124 $torch $vision $audio
        } catch {
            Write-ColorOutput "Fallback to CPU-only PyTorch" ([ConsoleColor]::Yellow)
            & python -m pip install --index-url https://download.pytorch.org/whl/cpu $torch $vision $audio
        }
    } else {
        Write-Host "No usable NVIDIA GPU detected (or nvidia-smi missing): installing CPU build"
        $env:PIP_INDEX_URL = "https://download.pytorch.org/whl/cpu"
        & python -m pip install --index-url https://download.pytorch.org/whl/cpu $torch $vision $audio
    }
}

function Install-ProjectRequirements {
    $req = Join-Path $ScriptRoot "requirements.txt"
    if (Test-Path -Path $req) {
        Write-ColorOutput "Installing requirements.txt (PyPI; filtering legacy 'argparse' if present)" ([ConsoleColor]::Yellow)
        # Create a temp requirements file that drops 'argparse' lines if any
        $tmpReq = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "requirements.sanitized.$([Guid]::NewGuid()).txt")
        try {
            Get-Content $req | Where-Object { $_ -notmatch "^\s*argparse(==|>=|<=|\s|$)" } | Set-Content -NoNewline $tmpReq
        } catch {
            # Fallback: if filtering fails, use the original file
            $tmpReq = $req
        }
        try {
            # Always use default PyPI here to avoid leaking the CUDA index into generic deps
            & python -m pip install -i https://pypi.org/simple -r $tmpReq
        } finally {
            if ($tmpReq -ne $req) { Remove-Item -Force -ErrorAction SilentlyContinue $tmpReq }
        }
    }
}

function Install-WhisperAndModels {
    # Presence check using importlib.util.find_spec (works on Py3.13)
    $null = Invoke-PythonCapture -Code @'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("whisper") else 1)
'@
    $needWhisper = $LASTEXITCODE
    if ($needWhisper -ne 0) {
        Write-ColorOutput "Installing openai-whisper" ([ConsoleColor]::Yellow)
        & python -m pip install -i https://pypi.org/simple --disable-pip-version-check openai-whisper
    }

    if ($DownloadModels) {
        Write-ColorOutput "Pre-scarico modelli Whisper base" ([ConsoleColor]::Cyan)
        Invoke-PythonScript -Code @'
import whisper
for m in ["base","small"]:
    try:
        whisper.load_model(m)
        print(f"downloaded: {m}")
    except Exception as e:
        print(f"warn: {m} -> {e}")
'@
    }
}

function Install-Diarization {
    if ($SkipDiarization) { return }

    # Token normalization (ENV/CLI only)
    $ResolvedHfToken = ""
    if ($HuggingFaceToken) { $ResolvedHfToken = $HuggingFaceToken }
    elseif ($env:HF_TOKEN) { $ResolvedHfToken = $env:HF_TOKEN }
    elseif ($env:HUGGINGFACE_HUB_TOKEN) { $ResolvedHfToken = $env:HUGGINGFACE_HUB_TOKEN }
    elseif ($env:HUGGING_FACE_HUB_TOKEN) { $ResolvedHfToken = $env:HUGGING_FACE_HUB_TOKEN }
    if ($ResolvedHfToken) {
        $env:HF_TOKEN = $ResolvedHfToken
        $env:HUGGINGFACE_HUB_TOKEN = $ResolvedHfToken
        $env:HUGGING_FACE_HUB_TOKEN = $ResolvedHfToken
    }

    # Compute Python version and eligibility (<= 3.11)
    $pyVer = try { (& python -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim() } catch { "0.0" }
    $pyOK = try { [version]$pyVer -le [version]'3.11' } catch { $false }

    # Always ensure Resemblyzer (default)
    Write-ColorOutput "Installing Resemblyzer (default diarization backend)" ([ConsoleColor]::Yellow)
    & python -m pip install -i https://pypi.org/simple --disable-pip-version-check resemblyzer scikit-learn

    if ($pyOK -and $ResolvedHfToken) {
        Write-ColorOutput "Installing pyannote.audio (Python <= 3.11 and HF token present)" ([ConsoleColor]::Yellow)
        & python -m pip install -i https://pypi.org/simple --disable-pip-version-check "pyannote.audio==3.*"
        if ($DownloadDiarizationModels) {
            Write-ColorOutput "Caching pyannote diarization model (best-effort)" ([ConsoleColor]::Cyan)
            Invoke-PythonScript -Code @'
try:
    from huggingface_hub import login
    import os
    tok = os.getenv('HF_TOKEN') or os.getenv('HUGGINGFACE_HUB_TOKEN') or os.getenv('HUGGING_FACE_HUB_TOKEN')
    if tok:
        try:
            login(token=tok, add_to_git_credential=False)
        except Exception:
            pass
    from pyannote.audio import Pipeline
    Pipeline.from_pretrained('pyannote/speaker-diarization-3.1')
    print('INFO pyannote model cached')
except Exception as e:
    print(f'WARN pyannote cache skipped: {e}')
'@
        }
    } else {
        Write-Host "INFO diarization: Python >3.11 or token missing; using Resemblyzer only."
    }
}

function Run-Smoke {
    if ($NoSmoke) { return }
    Write-ColorOutput "Smoke tests rapidi" ([ConsoleColor]::Cyan)

    Write-ColorOutput "Checking whisper implementation availability" ([ConsoleColor]::Cyan)
    try {
        $null = Invoke-PythonScript -Code @'
try:
    import whisper  # openai-whisper
    print("OK whisper import (openai-whisper)")
except Exception as e:
    try:
        from faster_whisper import WhisperModel
        print("OK whisper import (faster-whisper)")
    except Exception as e2:
        print(f"WARN no whisper implementation available: {e}")
'@
    } catch {
        Write-ColorOutput "WARN whisper diagnostic failed: $_" ([ConsoleColor]::Yellow)
    }

    if ($Verify) {
        try {
            $deadline = (Get-Date).AddSeconds(5)
            $files = Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.py -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\(\.venv|venv|\.git|dist|build|node_modules|__pycache__|\.cache|data|out)(\\|$)' }
            foreach ($f in $files) {
                if ((Get-Date) -gt $deadline) { break }
                $hit = Select-String -Path $f.FullName -SimpleMatch -Pattern 'importlib.util','find_spec(' -ErrorAction SilentlyContinue
                if ($hit) { Write-Host "WARN found legacy importlib check in: $($f.FullName)" -ForegroundColor Yellow; break }
            }
        } catch { }
    }

    Write-Host "Running CUDA diagnostic"
    try {
        if (Test-CudaAvailability) {
            Write-Host "CUDA diagnostic OK"
        } else {
            Write-Host "INFO CUDA diagnostic: skipped or unavailable"
        }
    } catch {
        Write-Host ("WARN CUDA diagnostic failed: {0}" -f $_.Exception.Message)
    }
}

function Configure-GitHubCli {
    if (-not $GitHubToken) { return }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return }
    try {
        & gh auth status *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Configuro gh auth con token" ([ConsoleColor]::Cyan)
            $env:GITHUB_TOKEN = $GitHubToken
            $env:GITHUB_TOKEN | & gh auth login --with-token
        }
    } catch {}
}

# Main
try {
    Ensure-Venv
    try { & python -m pip uninstall -y importlib *> $null } catch {}

    $ResolvedHfToken = ""
    if ($HuggingFaceToken) { $ResolvedHfToken = $HuggingFaceToken }
    elseif ($env:HF_TOKEN) { $ResolvedHfToken = $env:HF_TOKEN }
    elseif ($env:HUGGINGFACE_HUB_TOKEN) { $ResolvedHfToken = $env:HUGGINGFACE_HUB_TOKEN }
    elseif ($env:HUGGING_FACE_HUB_TOKEN) { $ResolvedHfToken = $env:HUGGING_FACE_HUB_TOKEN }
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
    Configure-GitHubCli

    Write-ColorOutput "Installazione completata." ([ConsoleColor]::Green)
    exit 0
} catch {
    Write-ColorOutput "Errore: $($_.Exception.Message)" ([ConsoleColor]::Red)
    exit 1
}
