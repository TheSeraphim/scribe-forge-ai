"""
Speaker diarization using pyannote.audio
"""

from pyannote.audio import Pipeline
import torch
from pathlib import Path


class Diarizer:
    """Handles speaker diarization"""
    
    def __init__(self, model_manager, logger):
        self.model_manager = model_manager
        self.logger = logger
    
    def diarize(self, audio_path):
        """
        Perform speaker diarization on audio file
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Diarization result with speaker segments
        """
        self.logger.info("Loading diarization pipeline...")
        pipeline = self.model_manager.get_diarization_pipeline()
        
        # Run diarization
        self.logger.info("Performing speaker diarization...")
        diarization = pipeline(str(audio_path))
        
        # Convert to our format
        formatted_result = self._format_diarization_result(diarization)
        
        num_speakers = len(set(segment["speaker"] for segment in formatted_result["segments"]))
        self.logger.info(f"Diarization completed: {num_speakers} speakers detected, {len(formatted_result['segments'])} segments")
        
        return formatted_result
    
    def _format_diarization_result(self, diarization):
        """
        Format pyannote diarization result
        
        Args:
            diarization: Raw pyannote diarization result
            
        Returns:
            Formatted diarization result
        """
        segments = []
        
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segment = {
                "start": turn.start,
                "end": turn.end,
                "speaker": speaker
            }
            segments.append(segment)
        
        # Sort segments by start time
        segments.sort(key=lambda x: x["start"])
        
        return {
            "segments": segments,
            "speakers": list(set(segment["speaker"] for segment in segments))
        }
    
    def align_with_transcription(self, transcription_result, diarization_result):
        """
        Align diarization results with transcription segments
        
        Args:
            transcription_result: Result from transcriber
            diarization_result: Result from diarization
            
        Returns:
            Aligned result with speaker labels for each transcription segment
        """
        self.logger.info("Aligning transcription with speaker diarization...")
        
        aligned_segments = []
        
        for trans_segment in transcription_result["segments"]:
            trans_start = trans_segment["start"]
            trans_end = trans_segment["end"]
            trans_mid = (trans_start + trans_end) / 2
            
            # Find the speaker for this segment
            speaker = self._find_speaker_at_time(diarization_result, trans_mid)
            
            aligned_segment = trans_segment.copy()
            aligned_segment["speaker"] = speaker
            aligned_segments.append(aligned_segment)
        
        # Update the transcription result
        result = transcription_result.copy()
        result["segments"] = aligned_segments
        result["speakers"] = diarization_result["speakers"]
        
        return result
    
    def _find_speaker_at_time(self, diarization_result, timestamp):
        """
        Find which speaker is active at a given timestamp
        
        Args:
            diarization_result: Diarization result
            timestamp: Time to check
            
        Returns:
            Speaker label or "Unknown"
        """
        for segment in diarization_result["segments"]:
            if segment["start"] <= timestamp <= segment["end"]:
                return segment["speaker"]
        
        return "Unknown"
