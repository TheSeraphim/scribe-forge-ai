# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an audio transcription tool with speaker diarization capabilities, built around OpenAI Whisper for transcription and multiple diarization backends (Resemblyzer for Python 3.12+, pyannote.audio for Python 3.11-). The tool processes audio files and outputs transcriptions in multiple formats (JSON, TXT, Markdown) with precise timestamps and optional speaker identification.

## Windows Usage

Windows users should use `run.ps1` which provides automatic virtual environment activation and parameter validation:

```powershell
.\run.ps1 audio.mp3 -o output --format txt --diarize
```

This is equivalent to `python main.py [args]` but handles environment setup automatically. See `QUICK_START_WINDOWS.md` for complete usage guide.

## Development Commands

### Setup and Installation
```bash
# Create virtual environment and setup
make setup

# Install development dependencies
make install-dev

# Full installation (preferred method)
./install.sh                    # Linux/macOS
.\install.ps1                   # Windows (run as Administrator)
```

### Code Quality and Testing
```bash
# Run linting and type checking
make lint

# Format code with black
make format

# Run tests (includes pytest + usage examples)
make test

# Complete quality checks (lint + test)
make check

# Pre-commit checks (format + lint)
make pre-commit
```

### Development Workflow
```bash
# Clean temporary files
make clean

# Clean downloaded models (frees space)
make clean-models

# Download base Whisper models
make download-models

# Download all Whisper models (large download)
make download-all-models

# Run usage examples
make examples

# Performance benchmark
make benchmark
```

### Docker Development
```bash
# Build Docker image
make docker-build

# Run with docker-compose
make docker-compose-up

# Clean Docker resources
make docker-clean
```

## Architecture Overview

### Core Components
- **main.py**: Entry point with argument parsing and workflow orchestration
- **src/transcriber.py**: Whisper-based transcription with timestamp extraction
- **src/diarizer.py**: Speaker diarization using Resemblyzer (primary) or pyannote.audio (fallback)
- **src/audio_processor.py**: Audio format conversion, cleaning, and preprocessing
- **src/model_manager.py**: AI model download and caching management
- **src/output_formatter.py**: Multi-format output generation (JSON/TXT/MD)
- **src/logger.py**: Timestamped logging system

### Key Design Patterns
- **Factory Pattern**: ModelManager creates and manages AI models
- **Strategy Pattern**: Different output formats and diarization backends
- **Dependency Injection**: Logger and ModelManager injected into components
- **Graceful Degradation**: Falls back when CUDA/diarization unavailable

### Python Version Compatibility
The system automatically adapts to Python versions:
- **Python 3.12+**: Uses Resemblyzer (no compilation issues, no tokens needed)
- **Python 3.11-**: Can use both Resemblyzer and pyannote.audio (requires HF token)

## Usage Patterns

### Basic Transcription
```bash
python main.py input.m4a -o output --format txt
```

### With Speaker Diarization
```bash
python main.py input.m4a -o output --format md --diarize
```

### High Quality with GPU
```bash
python main.py input.m4a -o output --format json --model-size large-v3 --clean-audio --diarize --device cuda
```

### Testing with Sample Data
```bash
make create-sample              # Creates test audio file
make transcribe-sample          # Basic transcription test
make transcribe-with-speakers   # Diarization test
```

## File Structure Context

### Critical Dependencies
- **whisper**: Core transcription engine
- **torch/torchaudio**: ML backend with optional CUDA support
- **resemblyzer**: Primary diarization (Python 3.12+)
- **pyannote.audio**: Alternative diarization (requires HF token)
- **librosa/soundfile**: Audio processing pipeline

### Model Management
- Models auto-download on first use to `models/` directory
- Whisper models: tiny (39MB) to large-v3 (1.5GB)
- Diarization models: Resemblyzer (~50MB), pyannote (~300MB)
- Use `--download-models` flag for pre-downloading

### Output Formats
- **JSON**: Complete structured data with metadata and word-level timestamps
- **TXT**: Human-readable format with speaker labels and timestamps
- **MD**: Markdown format organized by speaker sections

## Environment Configuration

### Key Environment Variables
```bash
# HuggingFace token for pyannote models
export HUGGINGFACE_HUB_TOKEN="hf_your_token"

# Force CPU usage
export CUDA_VISIBLE_DEVICES=""

# Custom model cache locations
export WHISPER_CACHE_DIR="/path/to/whisper/cache"
export HF_HOME="/path/to/huggingface/cache"
```

### Installation Scripts
- **install.ps1**: Windows PowerShell installer with automatic dependency handling
- **install.sh**: Linux/macOS installer with system detection
- Both handle Python version detection, CUDA setup, and model downloads

## Common Development Tasks

### Adding New Output Format
1. Extend `OutputFormatter._save_FORMAT()` method in `src/output_formatter.py`
2. Add format choice to argparse in `main.py:32`
3. Update format mapping in `main.py:62`

### Adding New Diarization Backend
1. Implement in `src/diarizer.py` following existing pattern
2. Add availability check in `ModelManager.is_diarization_available()`
3. Update installation scripts to handle new dependencies

### Performance Optimization
- Model selection impacts speed: tiny (~32x realtime) to large-v3 (~1x realtime)
- Audio cleaning adds processing time but improves quality
- GPU acceleration provides 2-5x speedup for larger models
- Use `make benchmark` to measure performance across models