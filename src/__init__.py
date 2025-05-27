"""
Audio Transcription Tool

Complete audio transcription system with speaker diarization using AI models.
Works completely offline with Whisper and PyAnnote models.

Main Features:
- Accurate transcription with Whisper models
- Speaker diarization to distinguish between speakers
- Precise timestamps for each segment and word
- Audio cleaning and format conversion
- Multiple output formats (JSON, TXT, Markdown)
- Offline operation - no external APIs required
- Detailed logging with timestamps

Usage:
    python main.py input.m4a -o output --format txt
    python main.py input.m4a -o output --format md --diarize
    python main.py input.m4a -o output --format json --model-size large-v3 --clean-audio

Modules:
    logger: Logging system with timestamp formatting
    audio_processor: Audio file processing and cleaning
    model_manager: AI model management and downloading
    transcriber: Audio transcription using Whisper
    diarizer: Speaker diarization using PyAnnote
    output_formatter: Output formatting for multiple formats

Author: Audio Transcription Team
Version: 1.0.0
License: MIT
"""

# Version information
__version__ = "1.0.0"
__author__ = "Audio Transcription Team"
__email__ = "contact@example.com"
__license__ = "MIT"

# Package metadata
__title__ = "audio-transcription-tool"
__description__ = "Complete audio transcription tool with speaker diarization"
__url__ = "https://github.com/yourusername/audio-transcription-tool"

# Import main components for easier access
try:
    from .logger import setup_logger
    from .audio_processor import AudioProcessor
    from .model_manager import ModelManager
    from .transcriber import Transcriber
    from .diarizer import Diarizer
    from .output_formatter import OutputFormatter
    
    # Define what gets imported with "from src import *"
    __all__ = [
        "setup_logger",
        "AudioProcessor", 
        "ModelManager",
        "Transcriber",
        "Diarizer", 
        "OutputFormatter"
    ]
    
except ImportError:
    # If running as standalone script, imports may not work
    # This is normal when running main.py directly
    pass

# Configuration constants
DEFAULT_MODEL_SIZE = "base"
DEFAULT_OUTPUT_FORMAT = "txt"
DEFAULT_LOG_LEVEL = "INFO"

SUPPORTED_AUDIO_FORMATS = [
    ".wav", ".mp3", ".m4a", ".flac", ".ogg", ".wma", ".aac"
]

SUPPORTED_OUTPUT_FORMATS = ["json", "txt", "md"]

WHISPER_MODEL_SIZES = [
    "tiny", "base", "small", "medium", "large", "large-v2", "large-v3"
]

# Model information
WHISPER_MODEL_INFO = {
    "tiny": {"params": "39M", "vram": "~1GB", "speed": "~32x", "quality": "Base"},
    "base": {"params": "74M", "vram": "~1GB", "speed": "~16x", "quality": "Good"},
    "small": {"params": "244M", "vram": "~2GB", "speed": "~6x", "quality": "Very Good"},
    "medium": {"params": "769M", "vram": "~5GB", "speed": "~2x", "quality": "Excellent"},
    "large": {"params": "1550M", "vram": "~10GB", "speed": "~1x", "quality": "Best"},
    "large-v2": {"params": "1550M", "vram": "~10GB", "speed": "~1x", "quality": "Best"},
    "large-v3": {"params": "1550M", "vram": "~10GB", "speed": "~1x", "quality": "Best"},
}

# Environment variables
HUGGINGFACE_TOKEN_ENV = "HUGGINGFACE_HUB_TOKEN"
WHISPER_CACHE_ENV = "WHISPER_CACHE_DIR"
HF_CACHE_ENV = "HF_HOME"

def get_version():
    """Get package version"""
    return __version__

def get_model_info(model_size=None):
    """Get information about Whisper models"""
    if model_size:
        return WHISPER_MODEL_INFO.get(model_size, {})
    return WHISPER_MODEL_INFO

def get_supported_formats():
    """Get supported audio and output formats"""
    return {
        "audio": SUPPORTED_AUDIO_FORMATS,
        "output": SUPPORTED_OUTPUT_FORMATS
    }

# Package initialization message
import sys
if "main.py" not in sys.argv[0]:  # Don't show when running main.py
    print(f"Audio Transcription Tool v{__version__} - Ready for offline transcription")
