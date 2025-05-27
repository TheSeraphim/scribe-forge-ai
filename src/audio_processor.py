"""
Audio processing utilities for cleaning and format conversion
"""

import os
import tempfile
from pathlib import Path
import subprocess
import librosa
import soundfile as sf
import numpy as np
from scipy.signal import wiener


class AudioProcessor:
    """Handles audio file processing and cleaning"""
    
    def __init__(self, logger):
        self.logger = logger
        self.temp_dir = tempfile.mkdtemp()
    
    def process_audio(self, input_path, clean_audio=False):
        """
        Process audio file: convert format and optionally clean
        
        Args:
            input_path: Path to input audio file
            clean_audio: Whether to apply audio cleaning
            
        Returns:
            Path to processed audio file
        """
        input_path = Path(input_path)
        
        # Generate output filename
        output_filename = f"processed_{input_path.stem}.wav"
        output_path = Path(self.temp_dir) / output_filename
        
        self.logger.info(f"Converting audio format: {input_path.suffix} -> .wav")
        
        # Load audio file
        try:
            audio, sr = librosa.load(str(input_path), sr=None, mono=True)
            self.logger.info(f"Loaded audio: {len(audio)/sr:.2f}s, {sr}Hz")
        except Exception as e:
            self.logger.error(f"Failed to load audio file: {e}")
            raise
        
        # Apply cleaning if requested
        if clean_audio:
            self.logger.info("Applying audio cleaning...")
            audio = self._clean_audio(audio, sr)
        
        # Normalize audio
        audio = self._normalize_audio(audio)
        
        # Save processed audio
        sf.write(str(output_path), audio, sr)
        self.logger.info(f"Processed audio saved to: {output_path}")
        
        return output_path
    
    def _clean_audio(self, audio, sr):
        """
        Apply basic audio cleaning techniques
        
        Args:
            audio: Audio signal
            sr: Sample rate
            
        Returns:
            Cleaned audio signal
        """
        # Remove silence at beginning and end
        audio = self._trim_silence(audio)
        
        # Apply Wiener filter for noise reduction
        audio = wiener(audio, noise=None)
        
        # Apply high-pass filter to remove low-frequency noise
        audio = self._high_pass_filter(audio, sr, cutoff=80)
        
        return audio
    
    def _trim_silence(self, audio, threshold=0.01):
        """Remove silence from beginning and end of audio"""
        # Find non-silent parts
        non_silent = np.abs(audio) > threshold
        
        if not np.any(non_silent):
            return audio
        
        # Find first and last non-silent sample
        start_idx = np.argmax(non_silent)
        end_idx = len(non_silent) - np.argmax(non_silent[::-1]) - 1
        
        return audio[start_idx:end_idx+1]
    
    def _high_pass_filter(self, audio, sr, cutoff=80):
        """Apply high-pass filter"""
        from scipy.signal import butter, filtfilt
        
        # Design filter
        nyquist = sr / 2
        normal_cutoff = cutoff / nyquist
        b, a = butter(1, normal_cutoff, btype='high', analog=False)
        
        # Apply filter
        filtered_audio = filtfilt(b, a, audio)
        
        return filtered_audio
    
    def _normalize_audio(self, audio):
        """Normalize audio to prevent clipping"""
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio = audio / max_val * 0.95
        return audio
    
    def cleanup(self):
        """Clean up temporary files"""
        import shutil
        try:
            shutil.rmtree(self.temp_dir)
            self.logger.info("Temporary files cleaned up")
        except Exception as e:
            self.logger.warning(f"Failed to cleanup temp files: {e}")
