#!/usr/bin/env python3
"""
Usage examples for the Audio Transcription Tool
Run these examples to test different features
"""

import subprocess
import sys
from pathlib import Path

def run_command(cmd, description):
    """Run a command and show the output"""
    print(f"\n{'='*60}")
    print(f"EXAMPLE: {description}")
    print(f"COMMAND: {' '.join(cmd)}")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("SUCCESS!")
        if result.stdout:
            print("OUTPUT:")
            print(result.stdout)
    except subprocess.CalledProcessError as e:
        print("ERROR!")
        print(f"Exit code: {e.returncode}")
        if e.stderr:
            print("STDERR:")
            print(e.stderr)
    except FileNotFoundError:
        print("ERROR: Command not found. Make sure the main script is executable.")

def main():
    """Run usage examples"""
    
    # Check if we have a sample audio file
    sample_files = [
        "sample.m4a",
        "sample.wav", 
        "sample.mp3",
        "test.m4a",
        "test.wav"
    ]
    
    audio_file = None
    for file in sample_files:
        if Path(file).exists():
            audio_file = file
            break
    
    if not audio_file:
        print("No sample audio file found. Please create or download a sample audio file.")
        print("Supported formats: M4A, WAV, MP3, FLAC")
        print("Save it as 'sample.m4a' or 'sample.wav' in the current directory.")
        return
    
    print(f"Using sample audio file: {audio_file}")
    
    # Example 1: Basic transcription
    run_command([
        "python", "main.py", audio_file,
        "-o", "example1_basic",
        "--format", "txt",
        "--log-level", "INFO"
    ], "Basic transcription to TXT format")
    
    # Example 2: Transcription with speaker diarization
    run_command([
        "python", "main.py", audio_file,
        "-o", "example2_speakers", 
        "--format", "md",
        "--diarize",
        "--log-level", "INFO"
    ], "Transcription with speaker diarization to Markdown")
    
    # Example 3: High-quality transcription with audio cleaning
    run_command([
        "python", "main.py", audio_file,
        "-o", "example3_quality",
        "--format", "json",
        "--model-size", "small",
        "--clean-audio",
        "--log-level", "DEBUG"
    ], "High-quality transcription with audio cleaning")
    
    # Example 4: Fast transcription
    run_command([
        "python", "main.py", audio_file,
        "-o", "example4_fast",
        "--format", "txt", 
        "--model-size", "tiny",
        "--log-level", "WARNING"
    ], "Fast transcription with tiny model")
    
    # Example 5: Download models first
    run_command([
        "python", "main.py", audio_file,
        "-o", "example5_download",
        "--format", "txt",
        "--download-models",
        "--model-size", "base"
    ], "Download models before transcription")
    
    # Example 6: Italian language transcription
    run_command([
        "python", "main.py", audio_file,
        "-o", "example6_italian",
        "--format", "md",
        "--language", "it",
        "--diarize"
    ], "Italian language transcription with speakers")
    
    print(f"\n{'='*60}")
    print("ALL EXAMPLES COMPLETED!")
    print("Check the generated files:")
    print("- example1_basic.txt")
    print("- example2_speakers.md") 
    print("- example3_quality.json")
    print("- example4_fast.txt")
    print("- example5_download.txt")
    print("- example6_italian.md")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
