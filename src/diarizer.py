"""
Speaker diarization using Resemblyzer (alternative to pyannote.audio)
"""

import numpy as np
import librosa
from resemblyzer import VoiceEncoder, preprocess_wav
from sklearn.cluster import AgglomerativeClustering
from pathlib import Path


class Diarizer:
    """Handles speaker diarization"""
    
    def __init__(self, model_manager, logger):
        self.model_manager = model_manager
        self.logger = logger
        self.encoder = None
    
    def _get_encoder(self):
        """Get or create Resemblyzer encoder"""
        if self.encoder is None:
            self.logger.info("Loading Resemblyzer voice encoder...")
            self.encoder = VoiceEncoder()
        return self.encoder
    
    def diarize(self, audio_path):
        """
        Perform speaker diarization on audio file
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Diarization result with speaker segments
        """
        self.logger.info("Loading audio for diarization...")
        
        # Load audio with librosa
        audio, sr = librosa.load(str(audio_path), sr=16000)
        
        # Segment audio into longer chunks for better accuracy
        self.logger.info("Segmenting audio...")
        segments, timestamps = self._segment_audio(audio, segment_length=20.0)  # Longer segments
        
        if len(segments) == 0:
            self.logger.warning("No audio segments found for diarization")
            return {"segments": [], "speakers": []}
        
        # Extract embeddings
        self.logger.info("Extracting speaker embeddings...")
        embeddings = self._extract_embeddings(segments)
        
        if len(embeddings) == 0:
            self.logger.warning("No embeddings extracted")
            return {"segments": [], "speakers": []}
        
        # Cluster speakers with conservative settings
        self.logger.info("Clustering speakers...")
        speaker_labels = self._cluster_speakers(embeddings, conservative=True)
        
        # Post-process to merge similar speakers
        speaker_labels = self._merge_similar_speakers(embeddings, speaker_labels)
        
        # Format result
        formatted_result = self._format_diarization_result(timestamps, speaker_labels)
        
        num_speakers = len(set(segment["speaker"] for segment in formatted_result["segments"]))
        self.logger.info(f"Diarization completed: {num_speakers} speakers detected, {len(formatted_result['segments'])} segments")
        
        return formatted_result
    
    def _segment_audio(self, audio, segment_length=20.0, sample_rate=16000):
        """Split audio into longer segments for better analysis"""
        segment_samples = int(segment_length * sample_rate)
        segments = []
        timestamps = []
        
        # Use overlap to improve boundary detection
        overlap = segment_samples // 4  # 25% overlap
        
        for i in range(0, len(audio), segment_samples - overlap):
            end_idx = min(i + segment_samples, len(audio))
            segment = audio[i:end_idx]
            
            # Only process segments longer than 5 seconds (increased from 1)
            if len(segment) > 5 * sample_rate:
                segments.append(segment)
                start_time = i / sample_rate
                end_time = end_idx / sample_rate
                timestamps.append((start_time, end_time))
        
        return segments, timestamps
    
    def _extract_embeddings(self, segments):
        """Extract speaker embeddings from audio segments"""
        encoder = self._get_encoder()
        embeddings = []
        
        for i, segment in enumerate(segments):
            try:
                # Preprocess for Resemblyzer
                processed = preprocess_wav(segment, source_sr=16000)
                
                # Require longer minimum length for better quality
                if len(processed) > 8000:  # Increased from 4000
                    embedding = encoder.embed_utterance(processed)
                    embeddings.append(embedding)
                else:
                    # Use zero embedding for short segments
                    embeddings.append(np.zeros(encoder.embedding_size))
                    
            except Exception as e:
                self.logger.warning(f"Failed to extract embedding for segment {i}: {e}")
                # Use zero embedding as fallback
                if len(embeddings) > 0:
                    embeddings.append(np.zeros_like(embeddings[0]))
                else:
                    embeddings.append(np.zeros(256))  # Default Resemblyzer size
        
        return np.array(embeddings)
    
    def _cluster_speakers(self, embeddings, conservative=True, n_speakers=None):
        """Cluster embeddings to identify speakers with conservative settings"""
        if len(embeddings) <= 1:
            return [0] * len(embeddings)
        
        # Use more conservative clustering for single speaker scenarios
        if conservative:
            # Higher threshold = less likely to split single speaker
            clustering = AgglomerativeClustering(
                n_clusters=None,
                distance_threshold=0.7,  # Increased from 0.5 (more conservative)
                linkage='average'  # Changed from 'ward' for better single speaker detection
            )
        else:
            # Use AgglomerativeClustering
            if n_speakers is None:
                # Auto-detect number of speakers (max 4, reduced from 6)
                max_speakers = min(4, len(embeddings))
                clustering = AgglomerativeClustering(
                    n_clusters=None,
                    distance_threshold=0.6,  # Slightly increased
                    linkage='average'
                )
            else:
                clustering = AgglomerativeClustering(
                    n_clusters=n_speakers,
                    linkage='average'
                )
        
        try:
            labels = clustering.fit_predict(embeddings)
            return labels
        except Exception as e:
            self.logger.warning(f"Clustering failed: {e}")
            # Fallback: all segments same speaker
            return [0] * len(embeddings)
    
    def _merge_similar_speakers(self, embeddings, labels):
        """Post-process to merge speakers that are too similar"""
        if len(set(labels)) <= 1:
            return labels
        
        # Calculate average embedding for each speaker
        unique_labels = list(set(labels))
        speaker_centroids = {}
        
        for label in unique_labels:
            speaker_embeddings = embeddings[np.array(labels) == label]
            if len(speaker_embeddings) > 0:
                speaker_centroids[label] = np.mean(speaker_embeddings, axis=0)
        
        # Merge speakers that are very similar
        similarity_threshold = 0.85  # High similarity = probably same person
        
        merged_labels = labels.copy()
        label_mapping = {}
        
        for i, label1 in enumerate(unique_labels):
            if label1 in label_mapping:
                continue
                
            for label2 in unique_labels[i+1:]:
                if label2 in label_mapping:
                    continue
                
                # Calculate cosine similarity
                centroid1 = speaker_centroids[label1]
                centroid2 = speaker_centroids[label2]
                
                similarity = np.dot(centroid1, centroid2) / (
                    np.linalg.norm(centroid1) * np.linalg.norm(centroid2)
                )
                
                if similarity > similarity_threshold:
                    # Merge label2 into label1
                    label_mapping[label2] = label1
                    self.logger.info(f"Merging similar speakers: SPEAKER_{label2:02d} -> SPEAKER_{label1:02d} (similarity: {similarity:.3f})")
        
        # Apply mapping
        for i, label in enumerate(merged_labels):
            if label in label_mapping:
                merged_labels[i] = label_mapping[label]
        
        return merged_labels
    
    def _format_diarization_result(self, timestamps, speaker_labels):
        """
        Format diarization result
        
        Args:
            timestamps: List of (start, end) tuples
            speaker_labels: Speaker labels for each segment
            
        Returns:
            Formatted diarization result
        """
        segments = []
        
        for i, (start, end) in enumerate(timestamps):
            if i < len(speaker_labels):
                speaker_id = speaker_labels[i]
                speaker = f"SPEAKER_{speaker_id:02d}"
            else:
                speaker = "SPEAKER_00"
            
            segment = {
                "start": start,
                "end": end,
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
        
        return "SPEAKER_00"  # Default speaker
