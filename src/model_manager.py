"""
Model management for Whisper and diarization models
"""

import os
from pathlib import Path
import whisper
import torch

# Try to import pyannote, but make it optional
try:
    from pyannote.audio import Pipeline
    PYANNOTE_AVAILABLE = True
except ImportError:
    Pipeline = None
    PYANNOTE_AVAILABLE = False

from huggingface_hub import hf_hub_download


class ModelManager:
    """Manages downloading and loading of AI models"""
    
    def __init__(self, logger):
        self.logger = logger
        self.models_dir = Path("models")
        self.models_dir.mkdir(exist_ok=True)
        
        # Check if CUDA is available
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.logger.info(f"Using device: {self.device}")
        
        # Log PyAnnote availability
        if PYANNOTE_AVAILABLE:
            self.logger.info("PyAnnote.audio available - speaker diarization enabled")
        else:
            self.logger.info("PyAnnote.audio not available - speaker diarization disabled")
    
    def download_whisper_model(self, model_size="base"):
        """
        Download Whisper model if not already present
        
        Args:
            model_size: Size of Whisper model to download
        """
        self.logger.info(f"Checking Whisper model: {model_size}")
        
        try:
            # This will download the model if not present
            model = whisper.load_model(model_size, device=self.device)
            self.logger.info(f"Whisper model '{model_size}' ready")
            return model
        except Exception as e:
            self.logger.error(f"Failed to load Whisper model: {e}")
            raise
    
    def download_diarization_model(self):
        """Download speaker diarization model"""
        if not PYANNOTE_AVAILABLE:
            self.logger.error("PyAnnote.audio not installed. Cannot download diarization model.")
            self.logger.error("Install with: pip install pyannote.audio")
            raise ImportError("PyAnnote.audio not available")
        
        self.logger.info("Checking speaker diarization model...")
        
        try:
            # Download the pyannote diarization model
            # This requires accepting the terms on HuggingFace
            pipeline = Pipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1",
                use_auth_token=None  # Set to your HF token if needed
            )
            self.logger.info("Diarization model ready")
            return pipeline
        except Exception as e:
            self.logger.error(f"Failed to load diarization model: {e}")
            self.logger.error("Note: You may need to accept terms at https://huggingface.co/pyannote/speaker-diarization-3.1")
            raise
    
    def get_whisper_model(self, model_size="base"):
        """Get loaded Whisper model"""
        return whisper.load_model(model_size, device=self.device)
    
    def get_diarization_pipeline(self):
        """Get loaded diarization pipeline"""
        if not PYANNOTE_AVAILABLE:
            raise ImportError("PyAnnote.audio not available. Install with: pip install pyannote.audio")
        
        return Pipeline.from_pretrained("pyannote/speaker-diarization-3.1")
    
    def is_diarization_available(self):
        """Check if diarization is available"""
        return PYANNOTE_AVAILABLE
    
    def list_available_models(self):
        """List available Whisper models"""
        return ["tiny", "base", "small", "medium", "large", "large-v2", "large-v3"]
    
    def get_model_info(self, model_size):
        """Get information about model size and requirements"""
        model_info = {
            "tiny": {"params": "39M", "vram": "~1GB", "speed": "~32x"},
            "base": {"params": "74M", "vram": "~1GB", "speed": "~16x"},
            "small": {"params": "244M", "vram": "~2GB", "speed": "~6x"},
            "medium": {"params": "769M", "vram": "~5GB", "speed": "~2x"},
            "large": {"params": "1550M", "vram": "~10GB", "speed": "~1x"},
            "large-v2": {"params": "1550M", "vram": "~10GB", "speed": "~1x"},
            "large-v3": {"params": "1550M", "vram": "~10GB", "speed": "~1x"},
        }
        return model_info.get(model_size, {})
