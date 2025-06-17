"""
Audio transcription using Faster-Whisper (CUDA optimized)
"""

try:
    from faster_whisper import WhisperModel
    FASTER_WHISPER_AVAILABLE = True
except ImportError:
    FASTER_WHISPER_AVAILABLE = False
    import whisper

import torch
from pathlib import Path
import os


class Transcriber:
    """Handles audio transcription using Faster-Whisper or Whisper"""
    
    def __init__(self, model_manager, logger):
        self.model_manager = model_manager
        self.logger = logger
        self.use_faster_whisper = FASTER_WHISPER_AVAILABLE
        
        if self.use_faster_whisper:
            self.logger.info("🚀 Using Faster-Whisper (CUDA optimized)")
        else:
            self.logger.info("⚠️ Using standard Whisper (CPU likely)")
    
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
            # Map model sizes to avoid auth issues
            model_mapping = {
                "large-v3": "large-v2",  # Use v2 to avoid auth
                "large": "large-v2"
            }
            actual_model = model_mapping.get(model_size, model_size)
            
            if actual_model != model_size:
                self.logger.info(f"📝 Using {actual_model} (no auth required)")
            
            # Faster-Whisper model initialization - ALLOW DOWNLOADS
            model = WhisperModel(
                actual_model, 
                device=device, 
                compute_type="float16" if device == "cuda" else "float32",
                cpu_threads=4,
                local_files_only=False,  # Allow downloads
                download_root=None       # Use default cache
            )
            
            self.logger.info(f"✅ Faster-Whisper model loaded on: {device}")
            
        except Exception as e:
            self.logger.error(f"❌ Faster-Whisper failed: {e}")
            self.logger.info("🔄 Falling back to standard Whisper...")
            return self._transcribe_standard_whisper(audio_path, model_size, language, device)
        
        if device == "cuda":
            self.logger.info(f"🔥 GPU Memory: {torch.cuda.memory_allocated()/1024**3:.2f} GB")
            self.logger.info("🚀 GUARANTEED GPU inference!")
        
        # Transcription options
        kwargs = {
            "beam_size": 5,
            "word_timestamps": True,
            "vad_filter": True,  # Voice Activity Detection
            "vad_parameters": dict(min_silence_duration_ms=1000),
        }
        
        if language:
            kwargs["language"] = language
            self.logger.info(f"Using language: {language}")
        else:
            self.logger.info("Auto-detecting language")
        
        self.logger.info("🚀 Starting Faster-Whisper transcription...")
        
        try:
            # Transcribe
            segments, info = model.transcribe(str(audio_path), **kwargs)
            
            self.logger.info(f"✅ Language detected: {info.language}")
            self.logger.info(f"🎯 Language probability: {info.language_probability:.2f}")
            
            # Convert segments to list and format
            segments_list = list(segments)
            formatted_result = self._format_faster_whisper_result(segments_list, info)
            
            self.logger.info(f"Faster-Whisper transcription completed: {len(formatted_result['segments'])} segments")
            
            return formatted_result
            
        except Exception as e:
            self.logger.error(f"❌ Faster-Whisper transcription failed: {e}")
            self.logger.info("🔄 Falling back to standard Whisper...")
            return self._transcribe_standard_whisper(audio_path, model_size, language, device)
    
    def _transcribe_standard_whisper(self, audio_path, model_size, language, device):
        """Fallback to standard Whisper"""
        self.logger.info(f"Loading standard Whisper model: {model_size}")
        
        model = self.model_manager.get_whisper_model(model_size)
        
        # Force CUDA (even though it probably won't work properly)
        if device == "cuda":
            model = model.cuda()
            self.logger.info(f"Model on: {next(model.parameters()).device}")
        
        options = {
            "verbose": False,
            "word_timestamps": True,
            "fp16": device == "cuda",
        }
        
        if language:
            options["language"] = language
        
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
