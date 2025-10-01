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
from src.output_formatter import OutputFormatter

# Try to import diarizer, but make it optional
try:
    from src.diarizer import Diarizer
    DIARIZER_AVAILABLE = True
except ImportError:
    Diarizer = None
    DIARIZER_AVAILABLE = False


def parse_args():
    parser = argparse.ArgumentParser(description="Audio Transcription Tool")
    parser.add_argument("input_file", type=str, help="Input audio file")
    parser.add_argument("-o", "--output", type=str, required=True, help="Output path (with or without extension)")
    parser.add_argument("--format", choices=["json", "txt", "md"], default="txt", help="Output format")
    parser.add_argument("--model-size", choices=["tiny","base","small","medium","large","large-v2","large-v3"], default="base", help="Whisper model size")
    parser.add_argument("--diarize", action="store_true", help="Enable speaker diarization")
    parser.add_argument("--language", type=str, default=None, help="Audio language (auto-detect if not specified)")
    parser.add_argument("--device", choices=["auto","cpu","cuda"], default="auto", help="Processing device")
    parser.add_argument("--download-models", action="store_true", help="Download models before processing")
    parser.add_argument("--log-level", choices=["DEBUG","INFO","WARNING","ERROR"], default="INFO", help="Logging level")
    parser.add_argument("--clean-audio", action="store_true", help="Apply audio cleaning/enhancement")
    parser.add_argument("-y", "--assume-yes", action="store_true",
                        help="Proceed even if requested context (CUDA/diarization) is unavailable")
    parser.add_argument("--create-output-dir", action="store_true",
                        help="Create output directory if missing")
    return parser.parse_args()


def main():
    """Main function"""
    args = parse_args()
    
    # Setup logging
    logger = setup_logger(args.log_level)
    logger.info("Starting audio transcription process")
    
    try:
        # ---------- Pre-flight: input path ----------
        input_path = Path(args.input_file)
        if not input_path.is_file():
            logger.error(f"Input file not found: {input_path}")
            sys.exit(2)

        # ---------- Pre-flight: normalize output path & directory ----------
        ext_map = {"json": ".json", "txt": ".txt", "md": ".md"}
        out_raw = Path(args.output)
        if out_raw.suffix:
            out_path = out_raw
        else:
            out_path = out_raw.with_suffix(ext_map[args.format])

        out_dir = out_path.parent if out_path.parent != Path("") else Path(".")
        if not out_dir.exists():
            if args.create_output_dir or args.assume_yes:
                out_dir.mkdir(parents=True, exist_ok=True)
                logger.info(f"Created output directory: {out_dir}")
            else:
                logger.error(f"Output directory does not exist: {out_dir}. Use --create-output-dir or -y.")
                sys.exit(2)

        # Canonical output path for downstream use
        args.output = str(out_path)

        # ---------- Pre-flight: device ----------
        wanted_device = args.device
        if wanted_device == "auto":
            try:
                import torch as _torch  # lazy import
                args.device = "cuda" if _torch.cuda.is_available() else "cpu"
            except Exception:
                args.device = "cpu"
            logger.info(f"Using device: {args.device}")
        elif wanted_device == "cuda":
            try:
                import torch as _torch
                if not _torch.cuda.is_available():
                    msg = "CUDA requested but not available. Will fall back to CPU."
                    if args.assume_yes:
                        logger.warning(msg)
                        args.device = "cpu"
                    else:
                        logger.error(msg + " Re-run with -y to proceed on CPU.")
                        sys.exit(2)
            except Exception:
                if args.assume_yes:
                    logger.warning("CUDA requested but torch is not usable. Falling back to CPU.")
                    args.device = "cpu"
                else:
                    logger.error("CUDA requested but torch is not usable. Re-run with -y to proceed on CPU.")
                    sys.exit(2)
        
        # Check diarization availability (prefer Resemblyzer; pyannote is optional)
        if args.diarize and not DIARIZER_AVAILABLE:
            msg = ("Speaker diarization requested but required packages are missing. "
                   "Install with: pip install resemblyzer scikit-learn  (or pyannote.audio on Py<=3.11)")
            if args.assume_yes:
                logger.warning(msg + " Proceeding with transcription only.")
                args.diarize = False
            else:
                logger.error(msg + " Re-run with -y to proceed without diarization.")
                sys.exit(2)
        
        # Initialize model manager
        model_manager = ModelManager(logger)
        
        # Check if diarization is available in model manager too
        if args.diarize and not model_manager.is_diarization_available():
            if args.assume_yes:
                logger.warning("Speaker diarization requested but not available. Proceeding with transcription only.")
                args.diarize = False
            else:
                logger.error("Speaker diarization requested but not available. Re-run with -y to proceed without diarization.")
                sys.exit(2)
        
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
        # Import Transcriber only when we are past pre-flight checks
        from src.transcriber import Transcriber
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
        
        # Post-save verification and canonical path
        final_path = Path(args.output)
        if not final_path.exists():
            logger.error(f"Expected output not found: {final_path}")
            sys.exit(2)
        # Post-save verification via logger (timestamped, machine-readable token preserved)
        logger.info(f"FINAL_OUTPUT: {final_path.resolve()}")

        logger.info("Transcription completed successfully!")
        
        # Show what was accomplished
        if diarization_result:
            logger.info("Transcription with speaker diarization completed")
        else:
            logger.info("[V] => Transcription completed (without speaker diarization)")
        
    except Exception as e:
        logger.error(f"Error during transcription: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
