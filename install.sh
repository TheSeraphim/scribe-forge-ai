#!/bin/bash

# Audio Transcription Tool - Installation Script
# Supports Ubuntu/Debian, macOS, and basic Windows setup

set -e

echo "=== Audio Transcription Tool Installation ==="
echo

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "Detected OS: $OS"
echo

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install system dependencies
install_system_deps() {
    echo "Installing system dependencies..."
    
    case $OS in
        "linux")
            if command_exists apt; then
                sudo apt update
                sudo apt install -y python3 python3-pip python3-venv ffmpeg
            elif command_exists yum; then
                sudo yum install -y python3 python3-pip ffmpeg
            elif command_exists dnf; then
                sudo dnf install -y python3 python3-pip ffmpeg
            else
                echo "Unsupported Linux distribution. Please install Python 3.8+, pip, and FFmpeg manually."
                exit 1
            fi
            ;;
        "macos")
            if ! command_exists brew; then
                echo "Homebrew not found. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python ffmpeg
            ;;
        "windows")
            echo "Please ensure you have:"
            echo "1. Python 3.8+ installed from python.org"
            echo "2. FFmpeg installed and in PATH"
            echo "Press Enter to continue..."
            read
            ;;
    esac
}

# Check Python version
check_python() {
    echo "Checking Python installation..."
    
    if command_exists python3; then
        PYTHON_CMD="python3"
    elif command_exists python; then
        PYTHON_CMD="python"
    else
        echo "Python not found. Please install Python 3.8 or later."
        exit 1
    fi
    
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    echo "Found Python $PYTHON_VERSION"
    
    # Check if version is >= 3.8
    PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)")
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
        echo "Python 3.8 or later is required. Found $PYTHON_VERSION"
        exit 1
    fi
}

# Create virtual environment
create_venv() {
    echo "Creating virtual environment..."
    
    if [ -d "venv" ]; then
        echo "Virtual environment already exists. Removing..."
        rm -rf venv
    fi
    
    $PYTHON_CMD -m venv venv
    
    # Activate virtual environment
    case $OS in
        "windows")
            source venv/Scripts/activate
            ;;
        *)
            source venv/bin/activate
            ;;
    esac
    
    echo "Virtual environment created and activated."
}

# Install Python dependencies
install_python_deps() {
    echo "Installing Python dependencies..."
    
    # Upgrade pip
    python -m pip install --upgrade pip
    
    # Install PyTorch first (for better compatibility)
    echo "Installing PyTorch..."
    if command_exists nvidia-smi && nvidia-smi > /dev/null 2>&1; then
        echo "NVIDIA GPU detected. Installing PyTorch with CUDA support..."
        pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118
    else
        echo "No NVIDIA GPU detected. Installing CPU-only PyTorch..."
        pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
    
    # Install other requirements
    echo "Installing other dependencies..."
    pip install -r requirements.txt
}

# Download initial models
download_models() {
    echo "Do you want to download the basic Whisper model now? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Downloading Whisper base model..."
        python -c "import whisper; whisper.load_model('base')"
        echo "Base model downloaded successfully."
    fi
}

# Setup HuggingFace token
setup_huggingface() {
    echo
    echo "=== HuggingFace Setup (for Speaker Diarization) ==="
    echo "To use speaker diarization, you need a HuggingFace account and token."
    echo "1. Create account at: https://huggingface.co"
    echo "2. Accept terms at: https://huggingface.co/pyannote/speaker-diarization-3.1"
    echo "3. Get token from: https://huggingface.co/settings/tokens"
    echo
    echo "Do you want to configure HuggingFace token now? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Enter your HuggingFace token:"
        read -r -s HF_TOKEN
        
        if [ -n "$HF_TOKEN" ]; then
            echo "export HUGGINGFACE_HUB_TOKEN=\"$HF_TOKEN\"" >> ~/.bashrc
            export HUGGINGFACE_HUB_TOKEN="$HF_TOKEN"
            echo "Token configured successfully."
        fi
    else
        echo "You can configure the token later by setting HUGGINGFACE_HUB_TOKEN environment variable."
    fi
}

# Test installation
test_installation() {
    echo
    echo "=== Testing Installation ==="
    
    # Test basic import
    python -c "
import whisper
import librosa
import soundfile
print('OK Basic imports successful')
"
    
    # Test Whisper model loading
    python -c "
import whisper
try:
    model = whisper.load_model('tiny')
    print('OK Whisper model loading successful')
except Exception as e:
    print(f'ERROR Whisper model loading failed: {e}')
"
    
    echo "Installation test completed."
}

# Main installation process
main() {
    echo "Starting installation process..."
    echo
    
    # Install system dependencies
    install_system_deps
    echo
    
    # Check Python
    check_python
    echo
    
    # Create virtual environment
    create_venv
    echo
    
    # Install Python dependencies
    install_python_deps
    echo
    
    # Download models
    download_models
    echo
    
    # Setup HuggingFace
    setup_huggingface
    echo
    
    # Test installation
    test_installation
    echo
    
    echo "=== Installation Complete! ==="
    echo
    echo "To get started:"
    echo "1. Activate the virtual environment:"
    case $OS in
        "windows")
            echo "   venv\\Scripts\\activate"
            ;;
        *)
            echo "   source venv/bin/activate"
            ;;
    esac
    echo "2. Run a test transcription:"
    echo "   python main.py your_audio_file.m4a -o output --format txt"
    echo
    echo "For more information, see README.md"
}

# Run main function
main "$@"
