"""
Output formatting for different file formats
"""

import json
from pathlib import Path
from datetime import datetime


class OutputFormatter:
    """Handles formatting and saving of transcription results"""
    
    def __init__(self, logger):
        self.logger = logger
    
    def save_output(self, transcription_result, diarization_result, output_path, format_type):
        """
        Save transcription result in specified format
        
        Args:
            transcription_result: Transcription result
            diarization_result: Optional diarization result
            output_path: Output file path (without extension)
            format_type: Output format (json, txt, md)
        """
        # Combine results if diarization was performed
        if diarization_result:
            from .diarizer import Diarizer
            diarizer = Diarizer(None, self.logger)
            final_result = diarizer.align_with_transcription(
                transcription_result, diarization_result
            )
        else:
            final_result = transcription_result
        
        # Determine final output path. If the provided path already has a suffix,
        # use it as-is; otherwise append the selected format extension.
        out = Path(output_path)
        if out.suffix.lower() in {".json", ".txt", ".md"}:
            output_file = out
        else:
            output_file = out.with_suffix(f".{format_type}")

        # Ensure parent directory exists
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Save in requested format
        if format_type == "json":
            self._save_json(final_result, output_file)
        elif format_type == "txt":
            self._save_txt(final_result, output_file)
        elif format_type == "md":
            self._save_markdown(final_result, output_file)
        
        self.logger.info(f"Output saved to: {output_file}")
    
    def _save_json(self, result, output_file):
        """Save result as JSON"""
        # Add metadata
        output_data = {
            "metadata": {
                "created_at": datetime.now().isoformat(),
                "language": result.get("language", "unknown"),
                "has_speakers": "speakers" in result,
                "total_segments": len(result["segments"])
            },
            "transcription": result
        }
        
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    def _save_txt(self, result, output_file):
        """Save result as plain text"""
        with open(output_file, "w", encoding="utf-8") as f:
            # Write header
            f.write(f"Audio Transcription\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Language: {result.get('language', 'unknown')}\n")
            
            if "speakers" in result:
                f.write(f"Speakers detected: {len(result['speakers'])}\n")
            
            f.write("\n" + "="*50 + "\n\n")
            
            # Write segments
            for segment in result["segments"]:
                timestamp = self._format_timestamp(segment["start"])
                
                if "speaker" in segment:
                    f.write(f"[{timestamp}] {segment['speaker']}: {segment['text']}\n")
                else:
                    f.write(f"[{timestamp}] {segment['text']}\n")
            
            # Write full text at the end
            f.write("\n" + "="*50 + "\n")
            f.write("FULL TRANSCRIPTION:\n\n")
            f.write(result["text"])
    
    def _save_markdown(self, result, output_file):
        """Save result as Markdown"""
        with open(output_file, "w", encoding="utf-8") as f:
            # Write header
            f.write("# Audio Transcription\n\n")
            f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n")
            f.write(f"**Language:** {result.get('language', 'unknown')}  \n")
            
            if "speakers" in result:
                f.write(f"**Speakers:** {len(result['speakers'])}  \n")
            
            f.write("\n---\n\n")
            
            # Write segments
            f.write("## Transcription with Timestamps\n\n")
            
            current_speaker = None
            for segment in result["segments"]:
                timestamp = self._format_timestamp(segment["start"])
                
                if "speaker" in segment:
                    speaker = segment['speaker']
                    
                    # Add speaker header if changed
                    if speaker != current_speaker:
                        f.write(f"\n### {speaker}\n\n")
                        current_speaker = speaker
                    
                    f.write(f"**{timestamp}**: {segment['text']}\n\n")
                else:
                    f.write(f"**{timestamp}**: {segment['text']}\n\n")
            
            # Write full text
            f.write("\n---\n\n")
            f.write("## Full Transcription\n\n")
            f.write(result["text"])
    
    def _format_timestamp(self, seconds):
        """Format timestamp as HH:MM:SS"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
