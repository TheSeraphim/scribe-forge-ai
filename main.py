#!/usr/bin/env python3
"""
Audio Transcription Tool with Speaker Diarization
Main entry point for the transcription system
"""

import argparse
import sys
import os
from pathlib import Path
from datetime import datetime

from src.logger import setup_logger
from src.audio_processor import AudioProcessor
from src.model_manager import ModelManager
from src.transcriber import Transcriber
from src.output_formatter import OutputFormatter

# Try to import diarizer, but make it optional
try:
    from src.diarizer import Diarizer
    DIARIZER_AVAILABLE = True
except ImportError:
    Diarizer = None
    DIARIZER_AVAILABLE = False


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Transcribe audio files with optional speaker diarization"
    )
    
    parser.add_argument(
        "input_file", 
        help="Input audio file path"
    )
    
    parser.add_argument(
        "-o", "--output", 
        help="Output file path (without extension)", 
        required=True
    )
    
    parser.add_argument(
        "--format", 
        choices=["json", "txt", "md"], 
        default="txt",
        help="Output format (default: txt)"
    )
    
    parser.add_argument(
        "--model-size", 
        choices=["tiny", "base", "small", "medium", "large", "large-v2", "large-v3"], 
        default="base",
        help="Whisper model size (default: base)"
    )
    
    parser.add_argument(
        "--diarize", 
        action="store_true",
        help="Enable speaker diarization (requires pyannote.audio)"
    )
    
    parser.add_argument(
        "--language", 
        default="auto",
        help="Audio language (auto-detect if not specified)"
    )
    
    parser.add_argument(
        "--download-models", 
        action="store_true",
        help="Download required models before processing"
    )
    
    parser.add_argument(
        "--log-level", 
        choices=["DEBUG", "INFO", "WARNING", "ERROR"], 
        default="INFO",
        help="Logging level (default: INFO)"
    )
    
    parser.add_argument(
        "--clean-audio", 
        action="store_true",
        help="Apply audio cleaning/enhancement"
    )
    
    return parser.parse_args()


def main():
    """Main function"""
    args = parse_arguments()
    
    # Setup logging
    logger = setup_logger(args.log_level)
    logger.info("Starting audio transcription process")
    
    try:
        # Validate input file
        input_path = Path(args.input_file)
        if not input_path.exists():
            logger.error(f"Input file not found: {input_path}")
            sys.exit(1)
        
        # Check diarization availability
        if args.diarize and not DIARIZER_AVAILABLE:
            logger.error("Speaker diarization requested but pyannote.audio not available")
            logger.error("Install with: pip install pyannote.audio")
            logger.info("Continuing with transcription only...")
            args.diarize = False
        
        # Initialize model manager
        model_manager = ModelManager(logger)
        
        # Check if diarization is available in model manager too
        if args.diarize and not model_manager.is_diarization_available():
            logger.error("Speaker diarization requested but not available")
            logger.info("Continuing with transcription only...")
            args.diarize = False
        
        # Download models if requested
        if args.download_models:
            logger.info("Downloading required models...")
            model_manager.download_whisper_model(args.model_size)
            if args.diarize:
                try:
                    model_manager.download_diarization_model()
                except Exception as e:
                    logger.error(f"Failed to download diarization model: {e}")
                    args.diarize = False
        
        # Initialize components
        audio_processor = AudioProcessor(logger)
        transcriber = Transcriber(model_manager, logger)
        output_formatter = OutputFormatter(logger)
        
        # Process audio file
        logger.info(f"Processing audio file: {input_path}")
        processed_audio_path = audio_processor.process_audio(
            input_path, 
            clean_audio=args.clean_audio
        )
        
        # Transcribe audio
        logger.info("Transcribing audio...")
        transcription_result = transcriber.transcribe(
            processed_audio_path,
            model_size=args.model_size,
            language=args.language if args.language != "auto" else None
        )
        
        # Perform speaker diarization if requested and available
        diarization_result = None
        if args.diarize and DIARIZER_AVAILABLE:
            logger.info("Performing speaker diarization...")
            diarizer = Diarizer(model_manager, logger)
            try:
                diarization_result = diarizer.diarize(processed_audio_path)
            except Exception as e:
                logger.error(f"Diarization failed: {e}")
                logger.info("Continuing with transcription only...")
        
        # Format and save output
        logger.info(f"Saving output in {args.format} format...")
        output_formatter.save_output(
            transcription_result,
            diarization_result,
            args.output,
            args.format
        )
        
        logger.info("Transcription completed successfully!")
        
        # Show what was accomplished
        if diarization_result:
            logger.info("✅ Transcription with speaker diarization completed")
        else:
            logger.info("✅ Transcription completed (without speaker diarization)")
        
    except Exception as e:
        logger.error(f"Error during transcription: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
