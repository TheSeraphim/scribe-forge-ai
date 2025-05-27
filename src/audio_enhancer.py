"""
Audio enhancement utilities for noise reduction and speech improvement
"""

import numpy as np
from scipy import signal
from scipy.signal import butter, filtfilt, wiener
import librosa
from tqdm import tqdm


class AudioEnhancer:
    """Handles audio enhancement for better transcription quality"""
    
    def __init__(self, logger):
        self.logger = logger
    
    def enhance_audio(self, audio, sr, preset="default", noise_level=0.5, dereverb=True, voice_isolation=True):
        """
        Main enhancement method that applies all improvements
        
        Args:
            audio: Audio signal array
            sr: Sample rate
            preset: Enhancement preset (default, meeting, podcast, phone)
            noise_level: Noise reduction aggressiveness (0.0 to 1.0)
            dereverb: Apply dereverberation
            voice_isolation: Apply voice frequency isolation
            
        Returns:
            Enhanced audio signal
        """
        self.logger.info(f"Enhancing audio with preset: {preset}")
        
        # Apply preset-specific settings
        if preset == "meeting":
            noise_level = 0.7
            dereverb = True
            voice_isolation = True
        elif preset == "podcast":
            noise_level = 0.4
            dereverb = False
            voice_isolation = True
        elif preset == "phone":
            noise_level = 0.8
            dereverb = True
            voice_isolation = True
        
        enhanced_audio = audio.copy()
        
        # Step 1: Noise reduction
        if noise_level > 0:
            self.logger.info(f"Applying noise reduction (level: {noise_level})")
            enhanced_audio = self._reduce_noise(enhanced_audio, sr, noise_level)
        
        # Step 2: Dereverberation
        if dereverb:
            self.logger.info("Applying dereverberation")
            enhanced_audio = self._remove_reverb(enhanced_audio, sr)
        
        # Step 3: Voice isolation
        if voice_isolation:
            self.logger.info("Applying voice isolation")
            enhanced_audio = self._isolate_voice(enhanced_audio, sr)
        
        # Step 4: Final normalization
        self.logger.info("Final normalization")
        enhanced_audio = self._normalize_audio(enhanced_audio)
        
        self.logger.info("Audio enhancement completed")
        return enhanced_audio
    
    def _reduce_noise(self, audio, sr, level):
        """
        Reduce background noise using spectral subtraction and Wiener filtering
        """
        # Processing in chunks for progress tracking
        chunk_size = max(1024, len(audio) // 100)  # At least 1024 samples per chunk
        total_samples = len(audio)
        
        with tqdm(total=total_samples, desc="Noise Reduction", unit="samples", leave=False) as pbar:
            # Estimate noise from first 0.5 seconds
            noise_sample_length = min(int(0.5 * sr), len(audio) // 4)
            noise_sample = audio[:noise_sample_length]
            
            # Calculate noise power spectrum
            noise_power = np.mean(np.abs(np.fft.fft(noise_sample))**2)
            pbar.update(noise_sample_length)
            
            # Process audio in chunks
            filtered_audio = np.zeros_like(audio)
            
            for i in range(0, len(audio), chunk_size):
                end_idx = min(i + chunk_size, len(audio))
                chunk = audio[i:end_idx]
                
                try:
                    # Apply Wiener filter to chunk
                    filtered_chunk = wiener(chunk, noise=noise_power * level)
                except:
                    # Fallback to high-pass filtering
                    filtered_chunk = self._high_pass_filter(chunk, sr, cutoff=80)
                
                filtered_audio[i:end_idx] = filtered_chunk
                pbar.update(len(chunk))
        
        # Apply spectral subtraction
        enhanced_audio = self._spectral_subtraction(filtered_audio, noise_sample, level)
        
        return enhanced_audio
    
    def _spectral_subtraction(self, audio, noise_sample, level):
        """
        Apply spectral subtraction to reduce noise
        """
        # Process in overlapping windows for smooth progress
        window_size = 2048
        hop_size = window_size // 2
        n_windows = (len(audio) - window_size) // hop_size + 1
        
        with tqdm(total=n_windows, desc="Spectral Subtraction", unit="windows", leave=False) as pbar:
            # Prepare noise spectrum
            noise_fft = np.fft.fft(noise_sample, n=window_size)
            noise_mag = np.abs(noise_fft)
            
            # Initialize output
            enhanced_audio = np.zeros_like(audio)
            window_counts = np.zeros_like(audio)
            
            # Process each window
            for i in range(n_windows):
                start_idx = i * hop_size
                end_idx = start_idx + window_size
                
                if end_idx > len(audio):
                    break
                
                # Get window
                window_audio = audio[start_idx:end_idx]
                
                # FFT
                audio_fft = np.fft.fft(window_audio)
                audio_mag = np.abs(audio_fft)
                audio_phase = np.angle(audio_fft)
                
                # Spectral subtraction
                enhanced_mag = audio_mag - level * noise_mag[:len(audio_mag)]
                enhanced_mag = np.maximum(enhanced_mag, 0.1 * audio_mag)
                
                # Reconstruct
                enhanced_fft = enhanced_mag * np.exp(1j * audio_phase)
                enhanced_window = np.real(np.fft.ifft(enhanced_fft))
                
                # Overlap-add
                enhanced_audio[start_idx:end_idx] += enhanced_window
                window_counts[start_idx:end_idx] += 1
                
                pbar.update(1)
            
            # Normalize overlapping regions
            enhanced_audio = np.divide(enhanced_audio, window_counts, 
                                     out=np.zeros_like(enhanced_audio), 
                                     where=window_counts!=0)
        
        return enhanced_audio
    
    def _remove_reverb(self, audio, sr):
        """
        Remove reverberation using inverse filtering
        """
        chunk_size = max(1024, len(audio) // 100)
        total_samples = len(audio)
        
        with tqdm(total=total_samples, desc="Dereverberation", unit="samples", leave=False) as pbar:
            # Apply high-pass filter in chunks
            enhanced_audio = np.zeros_like(audio)
            
            for i in range(0, len(audio), chunk_size):
                end_idx = min(i + chunk_size, len(audio))
                chunk = audio[i:end_idx]
                
                # Apply high-pass to remove low-frequency reverb
                filtered_chunk = self._high_pass_filter(chunk, sr, cutoff=120)
                
                # Apply compression
                compressed_chunk = self._compress_dynamic_range(filtered_chunk)
                
                enhanced_audio[i:end_idx] = compressed_chunk
                pbar.update(len(chunk))
        
        return enhanced_audio
    
    def _isolate_voice(self, audio, sr):
        """
        Isolate human voice frequencies (80Hz - 4kHz)
        """
        chunk_size = max(1024, len(audio) // 100)
        total_samples = len(audio)
        
        with tqdm(total=total_samples, desc="Voice Isolation", unit="samples", leave=False) as pbar:
            # Process in chunks
            enhanced_audio = np.zeros_like(audio)
            
            for i in range(0, len(audio), chunk_size):
                end_idx = min(i + chunk_size, len(audio))
                chunk = audio[i:end_idx]
                
                # Apply bandpass filter (80Hz - 4kHz)
                filtered_chunk = self._bandpass_filter(chunk, sr, 80, 4000)
                
                # Boost speech frequencies
                boosted_chunk = self._eq_boost_speech(filtered_chunk, sr)
                
                enhanced_audio[i:end_idx] = boosted_chunk
                pbar.update(len(chunk))
        
        return enhanced_audio
    
    def _high_pass_filter(self, audio, sr, cutoff=80):
        """Apply high-pass filter to remove low-frequency noise"""
        nyquist = sr / 2
        normal_cutoff = cutoff / nyquist
        b, a = butter(4, normal_cutoff, btype='high', analog=False)
        return filtfilt(b, a, audio)
    
    def _bandpass_filter(self, audio, sr, low_cutoff, high_cutoff):
        """Apply bandpass filter"""
        nyquist = sr / 2
        low = low_cutoff / nyquist
        high = high_cutoff / nyquist
        b, a = butter(4, [low, high], btype='band', analog=False)
        return filtfilt(b, a, audio)
    
    def _eq_boost_speech(self, audio, sr):
        """
        Apply EQ boost to speech frequencies
        """
        # Boost 300Hz - 3kHz range (main speech intelligibility)
        boost_audio = self._bandpass_filter(audio, sr, 300, 3000)
        
        # Mix with original (subtle boost)
        enhanced_audio = audio + 0.3 * boost_audio
        
        return enhanced_audio
    
    def _compress_dynamic_range(self, audio, threshold=0.1, ratio=4.0):
        """
        Apply dynamic range compression to reduce reverb tails
        """
        # Simple compressor
        compressed = audio.copy()
        
        # Find samples above threshold
        above_threshold = np.abs(audio) > threshold
        
        # Apply compression
        compressed[above_threshold] = np.sign(audio[above_threshold]) * (
            threshold + (np.abs(audio[above_threshold]) - threshold) / ratio
        )
        
        return compressed
    
    def _normalize_audio(self, audio):
        """Normalize audio to prevent clipping while maintaining dynamics"""
        # Find peak
        peak = np.max(np.abs(audio))
        
        if peak > 0:
            # Normalize to 90% of maximum to prevent clipping
            normalized = audio * (0.9 / peak)
        else:
            normalized = audio
        
        return normalized
    
    def get_enhancement_info(self, preset):
        """
        Get information about what enhancements will be applied
        """
        presets = {
            "default": {
                "description": "Balanced enhancement for general audio",
                "noise_reduction": 0.5,
                "dereverb": True,
                "voice_isolation": True
            },
            "meeting": {
                "description": "Optimized for meeting recordings with multiple speakers",
                "noise_reduction": 0.7,
                "dereverb": True,
                "voice_isolation": True
            },
            "podcast": {
                "description": "Light enhancement for good quality recordings",
                "noise_reduction": 0.4,
                "dereverb": False,
                "voice_isolation": True
            },
            "phone": {
                "description": "Aggressive enhancement for phone/low quality audio",
                "noise_reduction": 0.8,
                "dereverb": True,
                "voice_isolation": True
            }
        }
        
        return presets.get(preset, presets["default"])
