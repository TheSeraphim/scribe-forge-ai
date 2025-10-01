"""
Model management for Whisper and diarization models
"""

import os
import sys
from pathlib import Path
from importlib.util import find_spec

PY_MAJOR, PY_MINOR = sys.version_info[:2]
PYANNOTE_ALLOWED = (PY_MAJOR, PY_MINOR) < (3, 12)
RESEMBLYZER_AVAILABLE = find_spec("resemblyzer") is not None
PYANNOTE_AVAILABLE = PYANNOTE_ALLOWED and (find_spec("pyannote.audio") is not None)
# Avoid importing huggingface_hub at import time; not needed here


class ModelManager:
    """Manages downloading and loading of AI models"""
    
    def __init__(self, logger):
        self.logger = logger
        self.models_dir = Path("models")
        self.models_dir.mkdir(exist_ok=True)
        
        # Check if CUDA is available (lazy import torch)
        try:
            import torch as _torch  # type: ignore
            self.device = "cuda" if _torch.cuda.is_available() else "cpu"
        except Exception:
            self.device = "cpu"
        self.logger.info(f"Using device: {self.device}")
        
        # Log diarization backend availability (prefer Resemblyzer on Py >= 3.12)
        diar_backends = []
        if PYANNOTE_AVAILABLE:
            diar_backends.append("pyannote.audio")
        if RESEMBLYZER_AVAILABLE:
            diar_backends.append("resemblyzer")

        if diar_backends:
            self.logger.info(f"Diarization available: {', '.join(diar_backends)}")
        else:
            self.logger.info("Diarization backends not available")

    def diarization_backend(self) -> str:
        """Return preferred diarization backend name: 'resemblyzer', 'pyannote', or 'none'.
        Preference is Resemblyzer by default; pyannote used only if Resemblyzer unavailable.
        """
        if RESEMBLYZER_AVAILABLE:
            return "resemblyzer"
        if PYANNOTE_AVAILABLE:
            return "pyannote"
        return "none"

    def pyannote_is_eligible(self) -> bool:
        """Eligibility: Python <=3.11 and HF token available in environment."""
        if not PYANNOTE_ALLOWED:
            return False
        tok = os.getenv("HF_TOKEN") or os.getenv("HUGGINGFACE_HUB_TOKEN") or os.getenv("HUGGING_FACE_HUB_TOKEN")
        return bool(tok)
    
    def download_whisper_model(self, model_size="base"):
        """
        Download Whisper model if not already present
        
        Args:
            model_size: Size of Whisper model to download
        """
        self.logger.info(f"Checking Whisper model: {model_size}")
        
        try:
            # This will download the model if not present
            import whisper  # lazy import
            model = whisper.load_model(model_size, device=self.device)
            self.logger.info(f"Whisper model '{model_size}' ready")
            return model
        except Exception as e:
            self.logger.error(f"Failed to load Whisper model: {e}")
            raise
    
    def download_diarization_model(self):
        """Best-effort pre-cache for diarization backend (pyannote only)."""
        if self.diarization_backend() != "pyannote":
            return None
        if not self.pyannote_is_eligible():
            self.logger.info("pyannote not eligible; skipping pre-download")
            return None

        self.logger.info("Checking speaker diarization model (pyannote)...")
        try:
            from pyannote.audio import Pipeline  # import lazily
            pipeline = Pipeline.from_pretrained("pyannote/speaker-diarization-3.1")
            self.logger.info("pyannote diarization model cached")
            return pipeline
        except Exception as e:
            self.logger.warning(f"pyannote pre-download failed: {e}")
            return None
    
    def get_whisper_model(self, model_size="base"):
        """Get loaded Whisper model"""
        import whisper  # lazy import
        return whisper.load_model(model_size, device=self.device)
    
    def get_diarization_pipeline(self):
        """Get loaded diarization pipeline"""
        if not PYANNOTE_AVAILABLE:
            raise ImportError("PyAnnote.audio not available. Install with: pip install pyannote.audio")
        from pyannote.audio import Pipeline  # lazy import
        return Pipeline.from_pretrained("pyannote/speaker-diarization-3.1")
    
    def is_diarization_available(self):
        """Check if diarization is available"""
        return PYANNOTE_AVAILABLE or RESEMBLYZER_AVAILABLE
    
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
