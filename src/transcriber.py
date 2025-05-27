"""
Audio transcription using Whisper
"""

import whisper
from pathlib import Path


class Transcriber:
    """Handles audio transcription using Whisper"""
    
    def __init__(self, model_manager, logger):
        self.model_manager = model_manager
        self.logger = logger
    
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
        self.logger.info(f"Loading Whisper model: {model_size}")
        model = self.model_manager.get_whisper_model(model_size)
        
        # Prepare transcription options
        options = {
            "verbose": False,
            "word_timestamps": True,  # Enable word-level timestamps
        }
        
        if language:
            options["language"] = language
            self.logger.info(f"Using language: {language}")
        else:
            self.logger.info("Auto-detecting language")
        
        # Perform transcription
        self.logger.info("Starting transcription...")
        result = model.transcribe(str(audio_path), **options)
        
        # Log detected language
        if "language" in result:
            self.logger.info(f"Detected language: {result['language']}")
        
        # Process and format result
        formatted_result = self._format_transcription_result(result)
        
        self.logger.info(f"Transcription completed: {len(formatted_result['segments'])} segments")
        
        return formatted_result
    
    def _format_transcription_result(self, whisper_result):
        """
        Format Whisper result into standardized format
        
        Args:
            whisper_result: Raw Whisper transcription result
            
        Returns:
            Formatted transcription result
        """
        formatted_segments = []
        
        for segment in whisper_result["segments"]:
            formatted_segment = {
                "id": segment["id"],
                "start": segment["start"],
                "end": segment["end"],
                "text": segment["text"].strip(),
                "words": []
            }
            
            # Add word-level timestamps if available
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
        """
        Format timestamp in HH:MM:SS format
        
        Args:
            seconds: Time in seconds
            
        Returns:
            Formatted timestamp string
        """
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
