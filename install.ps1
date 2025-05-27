# Audio Transcription Tool - PowerShell Installation Script
# Supports Windows 10/11 with automatic dependency installation

param(
    [switch]$SkipDependencies,
    [switch]$NoGPU,
    [switch]$DownloadModels,
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
        return $pythonCmd
    }
    
    # Install Python using Chocolatey
    Write-ColorOutput "Installing Python 3.11..." -Color $Yellow
    try {
        choco install python --version=3.11.7 -y
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

function Create-VirtualEnvironment {
    param([string]$PythonCmd)
    
    Write-ColorOutput "Creating virtual environment..." -Color $Yellow
    
    # Remove existing venv
    if (Test-Path "venv") {
        Write-ColorOutput "Removing existing virtual environment..." -Color $Yellow
        Remove-Item -Recurse -Force "venv"
    }
    
    try {
        & $PythonCmd -m venv venv
        Write-ColorOutput "OK Virtual environment created" -Color $Green
        
        # Activate virtual environment
        & "venv\Scripts\Activate.ps1"
        Write-ColorOutput "OK Virtual environment activated" -Color $Green
        
        return $true
    }
    catch {
        Write-ColorOutput "ERROR Failed to create virtual environment: $($_.Exception.Message)" -Color $Red
        throw
    }
}

function Install-PythonDependencies {
    param([bool]$NoGPU)
    
    Write-ColorOutput "Installing Python dependencies..." -Color $Yellow
    
    try {
        # Upgrade pip
        Write-ColorOutput "Upgrading pip..." -Color $Yellow
        python -m pip install --upgrade pip
        
        # Install PyTorch first
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
                    Write-ColorOutput "NVIDIA GPU detected. Installing PyTorch with CUDA support..." -Color $Green
                    pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118
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
        
        # Install other requirements
        Write-ColorOutput "Installing other dependencies..." -Color $Yellow
        pip install -r requirements.txt
        
        Write-ColorOutput "OK Python dependencies installed successfully" -Color $Green
    }
    catch {
        Write-ColorOutput "ERROR Failed to install Python dependencies: $($_.Exception.Message)" -Color $Red
        throw
    }
}

function Download-Models {
    Write-ColorOutput "Downloading base Whisper model..." -Color $Yellow
    
    try {
        python -c "import whisper; whisper.load_model('base'); print('OK Base Whisper model downloaded')"
        Write-ColorOutput "OK Whisper model downloaded successfully" -Color $Green
    }
    catch {
        Write-ColorOutput "ERROR Failed to download Whisper model: $($_.Exception.Message)" -Color $Red
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
        # Test basic imports
        Write-ColorOutput "Testing basic imports..." -Color $Yellow
        python -c @"
import whisper
import librosa
import soundfile
import numpy as np
print('OK Basic imports successful')
"@
        
        # Test Whisper model loading
        Write-ColorOutput "Testing Whisper model loading..." -Color $Yellow
        python -c @"
import whisper
try:
    model = whisper.load_model('tiny')
    print('OK Whisper model loading successful')
except Exception as e:
    print(f'ERROR Whisper model loading failed: {e}')
"@
        
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
}

# Main installation function
function Main {
    Write-Header "Audio Transcription Tool - Windows Installation"
    Write-ColorOutput "PowerShell Installation Script for Windows 10/11" -Color $Blue
    
    try {
        # Check if running as administrator for system-wide installations
        if (-not (Test-Administrator)) {
            Write-ColorOutput "WARNING  Not running as Administrator. Some installations may require elevation." -Color $Yellow
            Write-ColorOutput "For best results, run PowerShell as Administrator" -Color $Yellow
            Write-Host ""
        }
        
        # Install system dependencies unless skipped
        if (-not $SkipDependencies) {
            Write-Header "Installing System Dependencies"
            Install-Chocolatey
            $pythonCmd = Install-Python
            Install-FFmpeg
            Install-Git
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
                throw "Python not found. Please install Python 3.8+ or run without -SkipDependencies"
            }
        }
        
        # Create virtual environment
        Write-Header "Setting Up Python Environment"
        Create-VirtualEnvironment -PythonCmd $pythonCmd
        
        # Install Python dependencies
        Install-PythonDependencies -NoGPU $NoGPU
        
        # Download models if requested
        if ($DownloadModels) {
            Write-Header "Downloading Models"
            Download-Models
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
        Write-ColorOutput "Please check the error message above and try again" -Color $Yellow
        exit 1
    }
}

# Help function
function Show-Help {
    Write-Host @"
Audio Transcription Tool - PowerShell Installation Script

USAGE:
    .\install.ps1 [OPTIONS]

OPTIONS:
    -SkipDependencies      Skip system dependency installation (Python, FFmpeg, etc.)
    -NoGPU                Force CPU-only PyTorch installation (no CUDA support)
    -DownloadModels       Download base Whisper models during installation
    -HuggingFaceToken     Specify HuggingFace token for speaker diarization
    -Help                 Show this help message

EXAMPLES:
    .\install.ps1                                    # Full installation
    .\install.ps1 -DownloadModels                   # Install and download models
    .\install.ps1 -SkipDependencies -NoGPU         # Python-only setup, CPU-only
    .\install.ps1 -HuggingFaceToken "your_token"   # Include HF token setup

REQUIREMENTS:
    - Windows 10/11
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)

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
