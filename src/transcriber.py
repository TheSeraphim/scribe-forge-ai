"""
Audio transcription using Faster-Whisper (CUDA optimized)
"""

# Do not import heavy backends at module import time.
from importlib.util import find_spec as _find_spec
WhisperModel = None
whisper = None

def _import_faster_whisper():
    global WhisperModel
    if WhisperModel is None:
        from faster_whisper import WhisperModel as _WM  # type: ignore
        WhisperModel = _WM
    return WhisperModel

def _import_openai_whisper():
    global whisper
    if whisper is None:
        import whisper as _w  # type: ignore
        whisper = _w
    return whisper

import torch
from pathlib import Path
import os
import sys
import time

def _configure_tqdm_default() -> None:
    """
    Force tqdm progress bars to render on stdout and remain enabled by default.
    Opt-out: set WHISPER_TQDM_DISABLE=1.
    """
    try:
        if os.getenv("WHISPER_TQDM_DISABLE", "0") == "1":
            # Respect explicit opt-out
            os.environ["TQDM_DISABLE"] = "1"
            return
        import tqdm as _tqdm_mod  # type: ignore
        _orig_tqdm = _tqdm_mod.tqdm
        def _tqdm_stdout(*args, **kwargs):
            kwargs.setdefault("file", sys.stdout)
            kwargs["disable"] = False
            return _orig_tqdm(*args, **kwargs)
        _tqdm_mod.tqdm = _tqdm_stdout  # type: ignore[attr-defined]
        os.environ.setdefault("TQDM_DISABLE", "0")
    except Exception:
        # Non-fatal: if patching fails, just proceed without raising
        pass


class Transcriber:
    """Handles audio transcription using Faster-Whisper or Whisper"""
    
    def __init__(self, model_manager, logger):
        self.model_manager = model_manager
        self.logger = logger
        # Ensure progress bars are visible by default and rendered to stdout
        _configure_tqdm_default()
        self.use_faster_whisper = (_find_spec("faster_whisper") is not None)
        
        if self.use_faster_whisper:
            self.logger.info("Using Faster-Whisper (CUDA optimized)")
        else:
            self.logger.info("Using standard Whisper (already working perfectly)")
    
    def transcribe(self, audio_path, model_size="base", language=None):
        """
        Transcribe audio file
        
        Args:
            audio_path: Path to audio file
            model_size: Whisper model size to use
            language: Language code (None for auto-detection)
            
        Returns:
            Transcription result with segments and timestamps
        """
        device = "cuda" if torch.cuda.is_available() else "cpu"
        
        if self.use_faster_whisper:
            return self._transcribe_faster_whisper(audio_path, model_size, language, device)
        else:
            return self._transcribe_standard_whisper(audio_path, model_size, language, device)
    
    def _transcribe_faster_whisper(self, audio_path, model_size, language, device):
        """Transcribe using Faster-Whisper (guaranteed CUDA)"""
        self.logger.info(f"🚀 Loading Faster-Whisper model: {model_size}")
        
        try:
            # Check for local model first
            local_model_path = f"./models/faster-whisper-{model_size}"
            if os.path.exists(local_model_path):
                self.logger.info(f"Using LOCAL model: {local_model_path}")
                model_path = local_model_path
            else:
                # Get HF token from environment
                hf_token = os.getenv("HF_TOKEN") or os.getenv("HUGGINGFACE_HUB_TOKEN")
                
                # Map model sizes to avoid auth issues for remote
                model_mapping = {
                    "large-v3": "large-v2",  # Use v2 to avoid auth
                    "large": "large-v2"
                }
                model_path = model_mapping.get(model_size, model_size)
                
                if model_path != model_size:
                    self.logger.info(f"Using {model_path} (no auth required)")
            
            # Faster-Whisper model initialization
            model_cls = _import_faster_whisper()
            model = model_cls(
                model_path, 
                device=device, 
                compute_type="float16" if device == "cuda" else "float32",
                cpu_threads=4,
                local_files_only=os.path.exists(local_model_path) if isinstance(model_path, str) and model_path.startswith('./') else False
            )
            
            self.logger.info(f"Faster-Whisper model loaded on: {device}")
            
        except Exception as e:
            self.logger.error(f"❌ Faster-Whisper failed: {e}")
            self.logger.info("🔄 Falling back to standard Whisper...")
            return self._transcribe_standard_whisper(audio_path, model_size, language, device)
        
        if device == "cuda":
            self.logger.info(f"GPU Memory: {torch.cuda.memory_allocated()/1024**3:.2f} GB")
            self.logger.info("GPU inference enabled")
        
        # Transcription options
        kwargs = {
            "beam_size": 5,
            "word_timestamps": True,
            "vad_filter": True,  # Voice Activity Detection
            "vad_parameters": dict(min_silence_duration_ms=1000),
            "condition_on_previous_text": False,  # Better for progress
            "compression_ratio_threshold": 2.4,
            "log_prob_threshold": -1.0,
            "no_speech_threshold": 0.6,
        }
        
        if language:
            kwargs["language"] = language
            self.logger.info(f"Using language: {language}")
        else:
            self.logger.info("Auto-detecting language")
        
        # Get audio duration for time estimates
        try:
            import librosa
            audio_duration = librosa.get_duration(path=str(audio_path))
            self.logger.info(f"Audio duration: {audio_duration:.1f} seconds ({audio_duration/60:.1f} minutes)")
            
            # Estimate processing time based on model size
            speed_estimates = {
                "tiny": 50, "base": 40, "small": 30, "medium": 25, "large": 15, "large-v2": 15, "large-v3": 15
            }
            estimated_speed = speed_estimates.get(model_size, 25)
            estimated_time = audio_duration / estimated_speed
            self.logger.info(f"Estimated processing time: ~{estimated_time:.1f} seconds ({estimated_time/60:.1f} minutes)")
        except:
            self.logger.info("📊 Audio duration: Unknown")
        
        self.logger.info("🚀 Starting Faster-Whisper transcription...")
        self.logger.info("💡 Monitor GPU usage in Task Manager to see processing activity!")
        
        start_time = time.time()
        
        try:
            # Transcribe
            segments, info = model.transcribe(str(audio_path), **kwargs)
            
            self.logger.info(f"Language detected: {info.language}")
            self.logger.info(f"Language probability: {info.language_probability:.2f}")
            
            # Convert segments to list with progress info
            self.logger.info("Processing transcription segments...")
            self.logger.info("Please wait while segments are being processed...")
            
            segments_list = []
            segment_count = 0
            last_log_time = time.time()
            
            for segment in segments:
                segments_list.append(segment)
                segment_count += 1
                
                # Log progress every 10 seconds
                current_time = time.time()
                if current_time - last_log_time > 10:
                    elapsed = current_time - start_time
                    self.logger.info(f"Processing... {segment_count} segments so far (elapsed: {elapsed:.1f}s)")
                    if hasattr(segment, 'end'):
                        self.logger.info(f"Current position: {segment.end:.1f}s")
                    last_log_time = current_time
            
            processing_time = time.time() - start_time
            
            # Show final results
            if len(segments_list) > 0:
                self.logger.info(f"Generated {len(segments_list)} segments")
                self.logger.info(f"Processing completed in {processing_time:.1f} seconds")
                
                # Calculate speed ratio
                if 'audio_duration' in locals():
                    speed_ratio = audio_duration / processing_time
                    self.logger.info(f"Speed: {speed_ratio:.1f}x real-time")
            else:
                self.logger.warning("⚠️ No segments generated - audio might be silent")
            
            formatted_result = self._format_faster_whisper_result(segments_list, info)
            
            self.logger.info(f"Faster-Whisper transcription completed: {len(formatted_result['segments'])} segments")
            
            return formatted_result
            
        except Exception as e:
            self.logger.error(f"Faster-Whisper transcription failed: {e}")
            self.logger.info("Falling back to standard Whisper...")
            return self._transcribe_standard_whisper(audio_path, model_size, language, device)
    
    def _transcribe_standard_whisper(self, audio_path, model_size, language, device):
        """Fallback to standard Whisper"""
        self.logger.info(f"Loading standard Whisper model: {model_size}")
        
        _w = _import_openai_whisper()
        model = self.model_manager.get_whisper_model(model_size)
        
        # Force CUDA (even though it probably won't work properly)
        if device == "cuda":
            model = model.cuda()
            self.logger.info(f"Model on: {next(model.parameters()).device}")
        
        # Avoid noisy Triton warnings from openai-whisper on systems without CUDA toolkit
        # by filtering specific UserWarnings from whisper.timing.
        import warnings
        warnings.filterwarnings(
            "ignore",
            message=r"Failed to launch Triton kernels, likely due to missing CUDA toolkit;.*",
            category=UserWarning,
            module="whisper.timing",
        )

        options = {
            "verbose": None,  # show tqdm bar but suppress transcript prints
            "word_timestamps": True,
            "fp16": device == "cuda",
        }

        # Ensure sensible tqdm defaults without overriding user configuration
        os.environ.setdefault("TQDM_DYNAMIC_NCOLS", "1")
        os.environ.setdefault("TQDM_MINCOLS", "80")
        os.environ.setdefault("WHISPER_TQDM_STDOUT", "1")

        # Audit: log effective whisper options at DEBUG
        try:
            self.logger.debug(
                "Effective whisper options: verbose=%s, fp16=%s, word_timestamps=%s",
                options.get("verbose"), options.get("fp16"), options.get("word_timestamps")
            )
        except Exception:
            pass
        
        if language:
            options["language"] = language
        
        # Run transcription (progress bar visible by default; logs go to stderr)
        result = model.transcribe(str(audio_path), **options)
        
        return self._format_transcription_result(result)
    
    def _format_faster_whisper_result(self, segments, info):
        """Format Faster-Whisper result"""
        formatted_segments = []
        full_text = ""
        
        for i, segment in enumerate(segments):
            formatted_segment = {
                "id": i,
                "start": segment.start,
                "end": segment.end,
                "text": segment.text.strip(),
                "words": []
            }
            
            # Add word-level timestamps
            if hasattr(segment, 'words') and segment.words:
                for word in segment.words:
                    formatted_word = {
                        "word": word.word,
                        "start": word.start,
                        "end": word.end,
                        "probability": word.probability
                    }
                    formatted_segment["words"].append(formatted_word)
            
            formatted_segments.append(formatted_segment)
            full_text += segment.text
        
        return {
            "text": full_text.strip(),
            "language": info.language,
            "segments": formatted_segments
        }
    
    def _format_transcription_result(self, whisper_result):
        """Format standard Whisper result"""
        formatted_segments = []
        
        for segment in whisper_result["segments"]:
            formatted_segment = {
                "id": segment["id"],
                "start": segment["start"],
                "end": segment["end"],
                "text": segment["text"].strip(),
                "words": []
            }
            
            if "words" in segment:
                for word in segment["words"]:
                    formatted_word = {
                        "word": word["word"],
                        "start": word["start"],
                        "end": word["end"],
                        "probability": word.get("probability", 1.0)
                    }
                    formatted_segment["words"].append(formatted_word)
            
            formatted_segments.append(formatted_segment)
        
        return {
            "text": whisper_result["text"],
            "language": whisper_result.get("language", "unknown"),
            "segments": formatted_segments
        }
    
    def _format_timestamp(self, seconds):
        """Format timestamp in HH:MM:SS format"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
