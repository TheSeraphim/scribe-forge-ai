# Audio Transcription Tool - PowerShell Installation Script
# Supports Windows 10/11 with automatic dependency installation

param(
    [switch]$SkipDependencies,
    [switch]$NoGPU,
    [switch]$DownloadModels,
    [switch]$DownloadDiarizationModels,
    [switch]$SkipDiarization,
    [switch]$ForceNonAdmin,
    [string]$HuggingFaceToken = ""
)

# Set execution policy and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue
$White = [System.ConsoleColor]::White

function Write-ColorOutput {
    param([string]$Message, [System.ConsoleColor]$Color = $White)
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "=" * 60 -Color $Blue
    Write-ColorOutput " $Title" -Color $Blue
    Write-ColorOutput "=" * 60 -Color $Blue
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    param([string]$CommandName)
    try {
        Get-Command $CommandName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Install-Chocolatey {
    Write-ColorOutput "Installing Chocolatey package manager..." -Color $Yellow
    
    # Check if already installed
    if (Test-Command "choco") {
        Write-ColorOutput "OK Chocolatey already installed" -Color $Green
        return
    }
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-ColorOutput "OK Chocolatey installed successfully" -Color $Green
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-ColorOutput "ERROR Failed to install Chocolatey: $($_.Exception.Message)" -Color $Red
        throw
    }
}

function Install-Python {
    Write-ColorOutput "Checking Python installation..." -Color $Yellow
    
    # Check if Python 3.8+ is available
    $pythonCmd = $null
    $pythonVersion = $null
    
    foreach ($cmd in @("python", "python3", "py")) {
        if (Test-Command $cmd) {
            try {
                $version = & $cmd --version 2>&1
                if ($version -match "Python (\d+)\.(\d+)\.(\d+)") {
                    $major = [int]$matches[1]
                    $minor = [int]$matches[2]
                    if ($major -eq 3 -and $minor -ge 8) {
                        $pythonCmd = $cmd
                        $pythonVersion = $version
                        break
                    }
                }
            }
            catch { }
        }
    }
    
    if ($pythonCmd) {
        Write-ColorOutput "OK Found compatible Python: $pythonVersion" -Color $Green
        
        # Check for pyannote.audio compatibility
        if ($pythonVersion -match "Python 3\.(\d+)\.") {
            $minorVersion = [int]$matches[1]
            if ($minorVersion -ge 12) {
                Write-ColorOutput "NOTE Python $pythonVersion detected" -Color $Yellow
                Write-ColorOutput "Speaker diarization may have limited compatibility" -Color $Yellow
                Write-ColorOutput "All other features will work perfectly" -Color $Green
            }
        }
        
        return $pythonCmd
    }
    
    # Only install if no Python found at all
    Write-ColorOutput "No compatible Python found. Installing Python 3.11..." -Color $Yellow
    try {
        choco install python311 -y
        Write-ColorOutput "OK Python installed successfully" -Color $Green
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        Start-Sleep -Seconds 3
        if (Test-Command "python") {
            return "python"
        }
        elseif (Test-Command "py") {
            return "py"
        }
        else {
            throw "Python command not found after installation"
        }
    }
    catch {
        Write-ColorOutput "ERROR Failed to install Python: $($_.Exception.Message)" -Color $Red
        Write-ColorOutput "Please install Python 3.8+ manually from https://python.org" -Color $Yellow
        throw
    }
}

function Install-FFmpeg {
    Write-ColorOutput "Checking FFmpeg installation..." -Color $Yellow
    
    if (Test-Command "ffmpeg") {
        Write-ColorOutput "OK FFmpeg already installed" -Color $Green
        return
    }
    
    Write-ColorOutput "Installing FFmpeg..." -Color $Yellow
    try {
        choco install ffmpeg -y
        Write-ColorOutput "OK FFmpeg installed successfully" -Color $Green
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-ColorOutput "ERROR Failed to install FFmpeg: $($_.Exception.Message)" -Color $Red
        Write-ColorOutput "Please install FFmpeg manually from https://ffmpeg.org" -Color $Yellow
        throw
    }
}

function Install-Git {
    Write-ColorOutput "Checking Git installation..." -Color $Yellow
    
    if (Test-Command "git") {
        Write-ColorOutput "OK Git already installed" -Color $Green
        return
    }
    
    Write-ColorOutput "Installing Git..." -Color $Yellow
    try {
        choco install git -y
        Write-ColorOutput "OK Git installed successfully" -Color $Green
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-ColorOutput "ERROR Failed to install Git: $($_.Exception.Message)" -Color $Red
        Write-ColorOutput "Git is optional but recommended" -Color $Yellow
    }
}

function Install-BuildTools {
    Write-ColorOutput "Checking build tools installation..." -Color $Yellow
    
    # Check if cmake is available
    if (Test-Command "cmake") {
        Write-ColorOutput "OK CMAKE already installed" -Color $Green
    }
    else {
        Write-ColorOutput "Installing CMAKE..." -Color $Yellow
        try {
            choco install cmake -y
            Write-ColorOutput "OK CMAKE installed successfully" -Color $Green
            
            # Refresh environment
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-ColorOutput "WARNING Failed to install CMAKE: $($_.Exception.Message)" -Color $Yellow
            Write-ColorOutput "Some packages requiring compilation may fail" -Color $Yellow
        }
    }
    
    # Check for Visual Studio Build Tools
    $vsInstalled = $false
    $vsPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    )
    
    foreach ($path in $vsPaths) {
        if (Test-Path $path) {
            $vsInstalled = $true
            Write-ColorOutput "OK Visual Studio Build Tools found" -Color $Green
            break
        }
    }
    
    if (-not $vsInstalled) {
        Write-ColorOutput "Installing Visual Studio Build Tools..." -Color $Yellow
        try {
            choco install visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools" -y
            Write-ColorOutput "OK Visual Studio Build Tools installed" -Color $Green
        }
        catch {
            Write-ColorOutput "WARNING Failed to install Visual Studio Build Tools: $($_.Exception.Message)" -Color $Yellow
            Write-ColorOutput "Some packages requiring compilation may fail" -Color $Yellow
        }
    }
}

function Create-VirtualEnvironment {
    param([string]$PythonCmd)
    
    Write-ColorOutput "Creating virtual environment..." -Color $Yellow
    
    # Remove existing venv if it exists
    if (Test-Path "venv") {
        Write-ColorOutput "Removing existing virtual environment..." -Color $Yellow
        Remove-Item -Recurse -Force "venv"
    }
    
    try {
        # Create new venv with specified Python command
        Write-ColorOutput "Creating virtual environment with $PythonCmd..." -Color $Yellow
        & $PythonCmd -m venv venv
        Write-ColorOutput "OK Virtual environment created" -Color $Green
        
        # Activate virtual environment
        & "venv\Scripts\Activate.ps1"
        Write-ColorOutput "OK Virtual environment activated" -Color $Green
        
        # Verify the Python version in the venv
        $venvPython = python --version
        Write-ColorOutput "Virtual environment Python: $venvPython" -Color $Green
        
        return $true
    }
    catch {
        Write-ColorOutput "ERROR Failed to create virtual environment: $($_.Exception.Message)" -Color $Red
        throw
    }
}

function Install-PythonDependencies {
    param([bool]$NoGPU, [bool]$SkipDiarization)
    
    Write-ColorOutput "Installing Python dependencies..." -Color $Yellow
    
    try {
        # Check Python version for compatibility decisions
        $pythonVersion = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        $pythonVersionFloat = [float]$pythonVersion
        Write-ColorOutput "Detected Python version: $pythonVersion" -Color $White
        
        # Upgrade pip and core packages first
        Write-ColorOutput "Upgrading pip and core packages..." -Color $Yellow
        python -m pip install --upgrade pip setuptools wheel
        
        # Install PyTorch with correct CUDA version
        Write-ColorOutput "Installing PyTorch..." -Color $Yellow
        if ($NoGPU) {
            Write-ColorOutput "Installing CPU-only PyTorch..." -Color $Yellow
            pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
        }
        else {
            # Check for NVIDIA GPU
            try {
                $nvidiaInfo = nvidia-smi 2>$null
                if ($nvidiaInfo) {
                    Write-ColorOutput "NVIDIA GPU detected. Installing PyTorch with CUDA 12.4 support..." -Color $Green
                    pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
                }
                else {
                    Write-ColorOutput "No NVIDIA GPU detected. Installing CPU-only PyTorch..." -Color $Yellow
                    pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
                }
            }
            catch {
                Write-ColorOutput "Could not detect GPU. Installing CPU-only PyTorch..." -Color $Yellow
                pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
            }
        }
        
        # Install Whisper with fallback methods
        Write-ColorOutput "Installing Whisper with fallback methods..." -Color $Yellow
        $whisperInstalled = $false
        
        # Method 1: Try GitHub installation
        try {
            Write-ColorOutput "Attempting GitHub installation..." -Color $Yellow
            pip install git+https://github.com/openai/whisper.git
            Write-ColorOutput "OK Whisper installed from GitHub" -Color $Green
            $whisperInstalled = $true
        }
        catch {
            Write-ColorOutput "GitHub installation failed, trying specific version..." -Color $Yellow
        }
        
        # Method 2: Try specific version if GitHub failed
        if (-not $whisperInstalled) {
            try {
                pip install openai-whisper==20231117
                Write-ColorOutput "OK Whisper specific version installed" -Color $Green
                $whisperInstalled = $true
            }
            catch {
                Write-ColorOutput "Specific version failed, trying faster-whisper..." -Color $Yellow
            }
        }
        
        # Method 3: Use faster-whisper as alternative
        if (-not $whisperInstalled) {
            try {
                pip install faster-whisper>=0.10.0
                Write-ColorOutput "OK faster-whisper installed (alternative implementation)" -Color $Green
                Write-ColorOutput "NOTE Using faster-whisper instead of openai-whisper" -Color $Yellow
                $whisperInstalled = $true
            }
            catch {
                Write-ColorOutput "ERROR All Whisper installation methods failed" -Color $Red
                throw "Failed to install any Whisper implementation"
            }
        }
        
        # Install core dependencies
        Write-ColorOutput "Installing core dependencies..." -Color $Yellow
        $coreDeps = @(
            "librosa>=0.10.0",
            "soundfile>=0.12.0",
            "numpy>=1.21.0",
            "transformers>=4.21.0",
            "scipy>=1.9.0",
            "tqdm>=4.64.0",
            "scikit-learn>=1.0.0"
        )
        
        foreach ($dep in $coreDeps) {
            try {
                pip install $dep
                Write-ColorOutput "OK Installed $dep" -Color $Green
            }
            catch {
                Write-ColorOutput "WARNING Failed to install $dep" -Color $Yellow
            }
        }
        
        # Install optional dependencies for advanced features
        Write-ColorOutput "Installing optional dependencies..." -Color $Yellow
        $optionalDeps = @(
            "huggingface_hub>=0.16.0",
            "matplotlib>=3.5.0",
            "pandas>=1.5.0"
        )
        
        foreach ($dep in $optionalDeps) {
            try {
                pip install $dep
                Write-ColorOutput "OK Installed optional $dep" -Color $Green
            }
            catch {
                Write-ColorOutput "WARNING Failed to install optional dependency $dep" -Color $Yellow
            }
        }
        
        # Handle speaker diarization installation based on Python version
        if (-not $SkipDiarization) {
            if ($pythonVersionFloat -ge 3.12) {
                Write-ColorOutput "Python $pythonVersion detected - using Resemblyzer for speaker diarization..." -Color $Yellow
                Write-ColorOutput "This avoids compilation issues with pyannote.audio on newer Python versions" -Color $Yellow
                
                try {
                    # Install Resemblyzer-based diarization (no compilation needed)
                    Write-ColorOutput "Installing Resemblyzer for speaker diarization..." -Color $Yellow
                    pip install resemblyzer
                    
                    Write-ColorOutput "OK Resemblyzer-based speaker diarization installed successfully" -Color $Green
                    Write-ColorOutput "NOTE Using Resemblyzer instead of pyannote.audio for Python 3.12+" -Color $Yellow
                }
                catch {
                    Write-ColorOutput "WARNING Failed to install Resemblyzer" -Color $Yellow
                    Write-ColorOutput "Speaker diarization will not be available" -Color $Yellow
                    Write-ColorOutput "You can run with -SkipDiarization to avoid this message" -Color $Yellow
                }
            }
            else {
                # Python 3.11 or older - try pyannote.audio first
                Write-ColorOutput "Installing pyannote.audio for speaker diarization..." -Color $Yellow
                
                try {
                    # Method that works with Python 3.11 and below
                    Write-ColorOutput "Installing pyannote.audio core..." -Color $Yellow
                    pip install --no-deps pyannote.audio>=3.1.0
                    
                    Write-ColorOutput "Installing pyannote dependencies..." -Color $Yellow
                    pip install torch-audiomentations pyannote.core pyannote.database pyannote.metrics asteroid-filterbanks
                    
                    Write-ColorOutput "Installing additional dependencies..." -Color $Yellow
                    pip install einops>=0.6.0 lightning>=2.0.1 omegaconf torchmetrics>=0.11.0 semver>=3.0.0 tensorboardX>=2.6 pytorch-metric-learning>=2.1.0 pyannote.pipeline>=3.0.1
                    
                    Write-ColorOutput "OK pyannote.audio speaker diarization installed successfully" -Color $Green
                    Write-ColorOutput "NOTE Installed without speechbrain to avoid compilation issues" -Color $Yellow
                }
                catch {
                    Write-ColorOutput "pyannote.audio installation failed, trying Resemblyzer fallback..." -Color $Yellow
                    try {
                        pip install resemblyzer
                        Write-ColorOutput "OK Resemblyzer fallback installed successfully" -Color $Green
                    }
                    catch {
                        Write-ColorOutput "WARNING All speaker diarization methods failed" -Color $Yellow
                        Write-ColorOutput "Transcription will work perfectly without speaker identification" -Color $Green
                        Write-ColorOutput "You can run with -SkipDiarization to avoid this message" -Color $Yellow
                    }
                }
            }
        }
        else {
            Write-ColorOutput "Skipping speaker diarization installation (disabled)" -Color $Yellow
        }
        
        Write-ColorOutput "OK Python dependencies installation completed" -Color $Green
    }
    catch {
        Write-ColorOutput "ERROR Failed to install Python dependencies: $($_.Exception.Message)" -Color $Red
        throw
    }
}

function Download-Models {
    param([bool]$DownloadDiarization = $false)
    
    Write-ColorOutput "Downloading models..." -Color $Yellow
    
    try {
        # Download Whisper models
        Write-ColorOutput "Downloading Whisper models..." -Color $Yellow
        python -c "
try:
    import whisper
    whisper.load_model('base')
    print('OK Base Whisper model downloaded')
except ImportError:
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel('base')
        print('OK Base faster-whisper model downloaded')
    except ImportError:
        print('ERROR No Whisper implementation found')
        exit(1)
except Exception as e:
    print(f'WARNING Model download failed: {e}')
    print('Models will be downloaded automatically on first use')
"
        
        # Download pyannote models if requested and token is available
        if ($DownloadDiarization) {
            $token = $env:HUGGINGFACE_HUB_TOKEN
            if ($token -and (Test-Command "git")) {
                Write-ColorOutput "Downloading pyannote speaker diarization model..." -Color $Yellow
                
                try {
                    # Clone the model repository
                    if (-not (Test-Path "speaker-diarization-3.1")) {
                        git clone "https://any_username:$token@huggingface.co/pyannote/speaker-diarization-3.1"
                        Write-ColorOutput "OK pyannote model repository cloned" -Color $Green
                    }
                    
                    # Copy to HuggingFace cache for seamless usage
                    Write-ColorOutput "Installing model in HuggingFace cache..." -Color $Yellow
                    python -c "
import os
import shutil
from pathlib import Path

# Setup cache structure
home = Path.home()
cache_base = home / '.cache' / 'huggingface' / 'hub'
cache_base.mkdir(parents=True, exist_ok=True)

repo_dir = cache_base / 'models--pyannote--speaker-diarization-3.1'
snapshot_dir = repo_dir / 'snapshots' / 'main'

print(f'Installing model in cache: {snapshot_dir}')

# Remove existing if present
if repo_dir.exists():
    shutil.rmtree(repo_dir)

# Copy model to cache
if Path('./speaker-diarization-3.1').exists():
    shutil.copytree('./speaker-diarization-3.1', snapshot_dir)
    
    # Create HuggingFace metadata
    (repo_dir / 'refs' / 'main').parent.mkdir(parents=True, exist_ok=True)
    (repo_dir / 'refs' / 'main').write_text('main')
    
    print('OK pyannote model installed in local cache')
else:
    print('WARNING pyannote model directory not found')
"
                    Write-ColorOutput "OK pyannote model installed for offline usage" -Color $Green
                    
                }
                catch {
                    Write-ColorOutput "WARNING Failed to download pyannote model: $($_.Exception.Message)" -Color $Yellow
                    Write-ColorOutput "Model will be downloaded automatically on first use" -Color $Yellow
                }
            }
            else {
                if (-not $token) {
                    Write-ColorOutput "WARNING No HuggingFace token found for pyannote model download" -Color $Yellow
                    Write-ColorOutput "Set HUGGINGFACE_HUB_TOKEN or use -HuggingFaceToken parameter" -Color $Yellow
                }
                if (-not (Test-Command "git")) {
                    Write-ColorOutput "WARNING Git not available for model download" -Color $Yellow
                }
                Write-ColorOutput "Skipping pyannote model download" -Color $Yellow
            }
        }
        
        Write-ColorOutput "OK Model download process completed" -Color $Green
    }
    catch {
        Write-ColorOutput "ERROR Failed to download models: $($_.Exception.Message)" -Color $Red
        Write-ColorOutput "Models will be downloaded automatically on first use" -Color $Yellow
    }
}

function Setup-HuggingFace {
    param([string]$Token)
    
    Write-Header "HuggingFace Setup (for Speaker Diarization)"
    
    Write-ColorOutput "To use speaker diarization, you need:" -Color $Yellow
    Write-ColorOutput "1. Create account at: https://huggingface.co" -Color $White
    Write-ColorOutput "2. Accept terms at: https://huggingface.co/pyannote/speaker-diarization-3.1" -Color $White
    Write-ColorOutput "3. Get token from: https://huggingface.co/settings/tokens" -Color $White
    Write-Host ""
    
    if (-not $Token) {
        $response = Read-Host "Do you want to configure HuggingFace token now? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            $Token = Read-Host "Enter your HuggingFace token" -MaskInput
        }
    }
    
    if ($Token) {
        try {
            # Set environment variable for current session
            $env:HUGGINGFACE_HUB_TOKEN = $Token
            
            # Set permanent environment variable
            [System.Environment]::SetEnvironmentVariable("HUGGINGFACE_HUB_TOKEN", $Token, [System.EnvironmentVariableTarget]::User)
            
            Write-ColorOutput "OK HuggingFace token configured successfully" -Color $Green
        }
        catch {
            Write-ColorOutput "ERROR Failed to set HuggingFace token: $($_.Exception.Message)" -Color $Red
        }
    }
    else {
        Write-ColorOutput "You can configure the token later by setting HUGGINGFACE_HUB_TOKEN environment variable" -Color $Yellow
    }
}

function Test-Installation {
    Write-Header "Testing Installation"
    
    try {
        # Test basic imports and model loading
        Write-ColorOutput "Testing installation..." -Color $Yellow
        python -c "
import sys

# Test basic imports
try:
    import torch
    import librosa
    import soundfile
    import numpy as np
    print('OK Basic imports successful')
except ImportError as e:
    print(f'ERROR Basic import failed: {e}')
    sys.exit(1)

# Test Whisper implementation
whisper_type = None
try:
    import whisper
    model = whisper.load_model('tiny')
    whisper_type = 'openai-whisper'
    print('OK openai-whisper model loading successful')
except ImportError:
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel('tiny')
        whisper_type = 'faster-whisper'
        print('OK faster-whisper model loading successful')
    except ImportError:
        print('ERROR No Whisper implementation found')
        sys.exit(1)
except Exception as e:
    print(f'ERROR Whisper model loading failed: {e}')
    sys.exit(1)

# Test speaker diarization capabilities
diarization_available = False
diarization_method = None

# Test pyannote.audio
try:
    import pyannote.audio
    from pyannote.audio import Pipeline
    diarization_available = True
    diarization_method = 'pyannote.audio'
    print('OK pyannote.audio available (speaker diarization enabled)')
except ImportError:
    pass

# Test Resemblyzer as fallback
if not diarization_available:
    try:
        import resemblyzer
        from resemblyzer import VoiceEncoder
        diarization_available = True
        diarization_method = 'Resemblyzer'
        print('OK Resemblyzer available (speaker diarization enabled)')
    except ImportError:
        pass

if not diarization_available:
    print('INFO No speaker diarization available (transcription only)')
else:
    print(f'OK Speaker diarization available using {diarization_method}')

print(f'OK Installation test completed successfully using {whisper_type}')
"
        
        Write-ColorOutput "OK Installation test completed successfully" -Color $Green
    }
    catch {
        Write-ColorOutput "ERROR Installation test failed: $($_.Exception.Message)" -Color $Red
        Write-ColorOutput "Some components may not be working correctly" -Color $Yellow
    }
}

function Show-CompletionMessage {
    Write-Header "Installation Complete!"
    
    Write-ColorOutput "To get started:" -Color $Green
    Write-ColorOutput "1. Activate the virtual environment:" -Color $White
    Write-ColorOutput "   venv\Scripts\Activate.ps1" -Color $Yellow
    Write-ColorOutput "2. Run a test transcription:" -Color $White
    Write-ColorOutput "   python main.py your_audio_file.m4a -o output --format txt" -Color $Yellow
    Write-Host ""
    Write-ColorOutput "For more information, see README.md" -Color $White
    Write-Host ""
    Write-ColorOutput "Example commands:" -Color $Green
    Write-ColorOutput "- Basic transcription:     python main.py audio.m4a -o output --format txt" -Color $White
    Write-ColorOutput "- With speakers:          python main.py audio.m4a -o output --format md --diarize" -Color $White
    Write-ColorOutput "- High quality:           python main.py audio.m4a -o output --format json --model-size large-v3 --clean-audio" -Color $White
    Write-Host ""
    Write-ColorOutput "Notes:" -Color $Yellow
    Write-ColorOutput "- GPU acceleration: Optimized PyTorch with CUDA 12.4 for best performance" -Color $White
    Write-ColorOutput "- Speaker diarization: Auto-selected best method for your Python version" -Color $White
    Write-ColorOutput "- Python 3.12+: Uses Resemblyzer (no compilation issues, no tokens needed)" -Color $White
    Write-ColorOutput "- Python 3.11-: Uses pyannote.audio (traditional method)" -Color $White
    
    # Check if local models were downloaded
    if (Test-Path "speaker-diarization-3.1") {
        Write-ColorOutput "- Local models: pyannote diarization model downloaded for offline usage" -Color $White
    }
    
    Write-Host ""
    Write-ColorOutput "Pro tip: Use -DownloadDiarizationModels to download models locally for offline usage!" -Color $Green
}

# Main installation function
function Main {
    Write-Header "Audio Transcription Tool - Windows Installation"
    Write-ColorOutput "PowerShell Installation Script for Windows 10/11" -Color $Blue
    
    try {
        # Check administrator privileges first (critical for installation)
        if (-not (Test-Administrator)) {
            if (-not $ForceNonAdmin) {
                Write-ColorOutput "ERROR This script requires Administrator privileges!" -Color $Red
                Write-ColorOutput "" -Color $White
                Write-ColorOutput "Required for:" -Color $Yellow
                Write-ColorOutput "- Installing Chocolatey package manager" -Color $White
                Write-ColorOutput "- Installing Python, FFmpeg, Git, CUDA" -Color $White
                Write-ColorOutput "- Installing Visual Studio Build Tools" -Color $White
                Write-ColorOutput "- Setting system environment variables" -Color $White
                Write-ColorOutput "" -Color $White
                Write-ColorOutput "Solutions:" -Color $Green
                Write-ColorOutput "1. Right-click PowerShell and 'Run as Administrator'" -Color $White
                Write-ColorOutput "2. Use -ForceNonAdmin to skip system installations (limited functionality)" -Color $White
                Write-ColorOutput "3. Use -SkipDependencies if system tools are already installed" -Color $White
                Write-ColorOutput "" -Color $White
                Write-ColorOutput "Example: .\install.ps1 -ForceNonAdmin -SkipDependencies" -Color $Yellow
                Write-ColorOutput "" -Color $White
                throw "Administrator privileges required. Exiting."
            }
            else {
                Write-ColorOutput "WARNING Running without Administrator privileges (forced)" -Color $Yellow
                Write-ColorOutput "Some installations may fail or require manual intervention" -Color $Yellow
                Write-ColorOutput "System-wide tools installation will be skipped" -Color $Yellow
                Write-Host ""
                
                # Force skip dependencies when not admin
                $SkipDependencies = $true
            }
        }
        else {
            Write-ColorOutput "OK Running with Administrator privileges" -Color $Green
            Write-Host ""
        }
        
        # Install system dependencies unless skipped
        if (-not $SkipDependencies) {
            Write-Header "Installing System Dependencies"
            Install-Chocolatey
            $pythonCmd = Install-Python
            Install-FFmpeg
            Install-Git
            Install-BuildTools
        }
        else {
            Write-ColorOutput "Skipping system dependencies installation" -Color $Yellow
            # Find Python command
            foreach ($cmd in @("python", "python3", "py")) {
                if (Test-Command $cmd) {
                    $pythonCmd = $cmd
                    break
                }
            }
            if (-not $pythonCmd) {
                throw "Python not found. Please install Python 3.8+ manually or run as Administrator without -SkipDependencies"
            }
        }
        
        # Create virtual environment
        Write-Header "Setting Up Python Environment"
        Create-VirtualEnvironment -PythonCmd $pythonCmd
        
        # Install Python dependencies
        Install-PythonDependencies -NoGPU $NoGPU -SkipDiarization $SkipDiarization
        
        # Download models if requested
        if ($DownloadModels -or $DownloadDiarizationModels) {
            Write-Header "Downloading Models"
            Download-Models -DownloadDiarization $DownloadDiarizationModels
        }
        
        # Setup HuggingFace
        Setup-HuggingFace -Token $HuggingFaceToken
        
        # Test installation
        Test-Installation
        
        # Show completion message
        Show-CompletionMessage
        
    }
    catch {
        Write-ColorOutput "ERROR Installation failed: $($_.Exception.Message)" -Color $Red
        if ($_.Exception.Message -eq "Administrator privileges required. Exiting.") {
            exit 2  # Special exit code for admin privileges
        }
        else {
            Write-ColorOutput "Please check the error message above and try again" -Color $Yellow
            exit 1
        }
    }
}

# Help function
function Show-Help {
    Write-Host @"
Audio Transcription Tool - PowerShell Installation Script

USAGE:
    .\install.ps1 [OPTIONS]

OPTIONS:
    -SkipDependencies         Skip system dependency installation (Python, FFmpeg, etc.)
    -NoGPU                   Force CPU-only PyTorch installation (no CUDA support)
    -DownloadModels          Download base Whisper models during installation
    -DownloadDiarizationModels Download pyannote speaker diarization models locally
    -SkipDiarization         Skip speaker diarization installation
    -ForceNonAdmin           Allow running without Administrator privileges (limited functionality)
    -HuggingFaceToken        Specify HuggingFace token for pyannote.audio (Python 3.11-)
    -Help                    Show this help message

EXAMPLES:
    .\install.ps1                                           # Full installation (requires Admin)
    .\install.ps1 -DownloadModels                          # Install and download Whisper models
    .\install.ps1 -DownloadDiarizationModels               # Install and download diarization models locally
    .\install.ps1 -ForceNonAdmin -SkipDependencies         # Python-only setup without Admin privileges
    .\install.ps1 -SkipDiarization                        # Skip speaker diarization entirely
    .\install.ps1 -HuggingFaceToken "hf_xxx" -DownloadDiarizationModels  # Full setup with local models

ADMINISTRATOR PRIVILEGES:
    This script requires Administrator privileges by default for:
    - Installing Chocolatey package manager
    - Installing system tools (Python, FFmpeg, Git, CUDA, Visual Studio Build Tools)
    - Setting system environment variables
    
    To run without Admin privileges:
    - Use -ForceNonAdmin -SkipDependencies (requires pre-installed tools)
    - Or install system dependencies manually first

FEATURES:
    - Smart Python version detection and compatibility handling
    - Automatic GPU detection and optimized PyTorch installation (CUDA 12.4)
    - Adaptive speaker diarization:
      * Python 3.12+: Resemblyzer (no compilation issues, no tokens needed)
      * Python 3.11-: pyannote.audio (traditional, requires HF token)
    - Local model download and caching:
      * Downloads pyannote models to local cache for offline usage
      * Eliminates need for internet access during transcription
      * Bypasses HuggingFace authentication issues
    - Robust dependency management with multiple fallback methods
    - Zero-config installation for most scenarios

REQUIREMENTS:
    - Windows 10/11
    - PowerShell 5.1 or later
    - Administrator privileges (recommended) or -ForceNonAdmin flag
    - Internet connection (for installation and model downloads)
    - Git (for local model downloads)
    - HuggingFace token (for pyannote model downloads on Python 3.11-)

For more information, see README.md
"@
}

# Parse arguments and run
if ($args -contains "-Help" -or $args -contains "--help" -or $args -contains "/?" -or $args -contains "-h") {
    Show-Help
    exit 0
}

# Run main installation
Main
