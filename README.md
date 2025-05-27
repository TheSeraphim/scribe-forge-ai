# Audio Transcription Tool

Complete system for audio transcription with speaker diarization, using AI models that work entirely offline.

## Features

- **Accurate transcription** using OpenAI Whisper models
- **Speaker diarization** to distinguish between speakers
- **Precise timestamps** for every segment and word
- **Automatic audio cleaning** to improve quality
- **Support for multiple formats** (M4A, WAV, MP3, FLAC, etc.)
- **Multiple output types** (JSON, TXT, Markdown)
- **Offline operation** - no external APIs required
- **Detailed logging** with precise timestamps

## Installation

### 1. System Prerequisites

**On Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install python3 python3-pip ffmpeg
```

**On macOS:**
```bash
brew install python ffmpeg
```

**On Windows:**
- Install Python 3.8+ from python.org
- Install FFmpeg from https://ffmpeg.org/download.html

### 2. Python Installation

```bash
# Clone or download the project
cd audio-transcription-tool

# Create a virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 3. HuggingFace Configuration (for diarization)

To use speaker diarization you must:

1. Create an account on https://huggingface.co
2. Accept the model terms: https://huggingface.co/pyannote/speaker-diarization-3.1
3. Obtain an access token from https://huggingface.co/settings/tokens
4. Configure the token:

```bash
# Option 1: Environment variable
export HUGGINGFACE_HUB_TOKEN="your_token_here"

# Option 2: HuggingFace CLI login
pip install huggingface_hub[cli]
huggingface-cli login
```

## Models Used

### Whisper (Transcription)
Whisper models are downloaded automatically on first use:

| Model | Size | VRAM | Speed | Quality |
|-------|------|------|-------|---------|
| tiny    | 39 MB  | ~1GB | ~32x | Basic |
| base    | 74 MB  | ~1GB | ~16x | Good |
| small   | 244 MB | ~2GB | ~6x  | Very good |
| medium  | 769 MB | ~5GB | ~2x  | Excellent |
| large-v3| 1550 MB| ~10GB| ~1x  | Best |

### PyAnnote (Diarization)
- **Model**: `pyannote/speaker-diarization-3.1`
- **Size**: ~300MB
- **Requirements**: Accept HuggingFace terms

## Usage

### Basic Examples

```bash
# Simple transcription
python main.py input.m4a -o output --format txt

# With speaker diarization
python main.py input.m4a -o output --format md --diarize

# With audio cleaning and best model
python main.py input.m4a -o output --format json --model-size large-v3 --clean-audio

# Download models before running
python main.py input.m4a -o output --download-models --diarize
```

### Full Parameters

```bash
python main.py INPUT_FILE -o OUTPUT_PATH [OPTIONS]

Required arguments:
  INPUT_FILE                Input audio file
  -o, --output OUTPUT_PATH  Output path (without extension)

Options:
  --format {json,txt,md}    Output format (default: txt)
  --model-size {tiny,base,small,medium,large,large-v2,large-v3}
                            Whisper model size (default: base)
  --diarize                 Enable speaker diarization
  --language LANG           Audio language (auto-detect if not specified)
  --download-models         Download models before processing
  --log-level {DEBUG,INFO,WARNING,ERROR}
                            Logging level (default: INFO)
  --clean-audio             Apply audio cleaning
```

### Practical Examples

```bash
# Italian meeting with 3 participants
python main.py meeting.m4a -o meeting_transcript \
  --format md --diarize --language it --clean-audio

# English interview, JSON output for further processing
python main.py interview.wav -o interview_data \
  --format json --model-size medium --diarize

# Long podcast, best model
python main.py podcast.mp3 -o podcast_transcript \
  --format txt --model-size large-v3 --log-level DEBUG
```

## Output Structure

### TXT Format
```
Audio Transcription
Generated: 2025-05-25 14:30:00
Language: italian
Speakers detected: 2

==================================================

[00:00:05] SPEAKER_00: Good morning and welcome to our meeting.
[00:00:12] SPEAKER_01: Thank you, I'm happy to be here.
[00:00:18] SPEAKER_00: Let's start with the first item on the agenda.
```

### JSON Format
```json
{
  "metadata": {
    "created_at": "2025-05-25T14:30:00",
    "language": "italian",
    "has_speakers": true,
    "total_segments": 45
  },
  "transcription": {
    "text": "Full transcription text...",
    "language": "italian",
    "segments": [
      {
        "id": 0,
        "start": 5.2,
        "end": 8.7,
        "text": "Good morning and welcome",
        "speaker": "SPEAKER_00",
        "words": [
          {
            "word": "Good",
            "start": 5.2,
            "end": 5.8,
            "probability": 0.95
          }
        ]
      }
    ]
  }
}
```

### Markdown Format
```markdown
# Audio Transcription

**Generated:** 2025-05-25 14:30:00  
**Language:** italian  
**Speakers:** 2

---

## Transcription with Timestamps

### SPEAKER_00

**00:00:05**: Good morning and welcome to our meeting.

**00:00:18**: Let's start with the first item on the agenda.

### SPEAKER_01

**00:00:12**: Thank you, I'm happy to be here.
```

## Logging

The system uses detailed logging with timestamps in the format `[yyyyMMdd-HHmmss]`:

```
[20250525-143000] INFO - Starting audio transcription process
[20250525-143001] INFO - Processing audio file: meeting.m4a
[20250525-143002] INFO - Converting audio format: .m4a -> .wav
[20250525-143005] INFO - Loaded audio: 1547.2s, 16000Hz
[20250525-143006] INFO - Loading Whisper model: base
[20250525-143008] INFO - Starting transcription...
[20250525-143045] INFO - Detected language: italian
[20250525-143046] INFO - Performing speaker diarization...
[20250525-143078] INFO - Diarization completed: 2 speakers detected
[20250525-143079] INFO - Saving output in md format...
[20250525-143080] INFO - Transcription completed successfully!
```

## Troubleshooting

### Common Errors

**1. Diarization model error**
```
Failed to load diarization model
```
- Make sure you accepted the terms on HuggingFace
- Check the authentication token

**2. CUDA error**
```
CUDA out of memory
```
- Use a smaller model: `--model-size small`
- Force CPU usage: set `CUDA_VISIBLE_DEVICES=""`

**3. Audio format error**
```
Failed to load audio file
```
- Verify that FFmpeg is installed
- Check that the audio file is not corrupted

### Performance Optimization

**For long files (>1 hour):**
- Use `--model-size small` or `base`
- Avoid `--clean-audio` if not needed
- Increase available RAM

**For best quality:**
- Use `--model-size large-v3`
- Enable `--clean-audio`
- Use `--diarize` only if necessary

**For maximum speed:**
- Use `--model-size tiny`
- Disable diarization
- Do not use audio cleaning

## Supported Audio Formats

- **Input**: M4A, WAV, MP3, FLAC, OGG, WMA, AAC
- **Internal processing**: WAV 16kHz mono
- **Maximum duration**: Limited only by available memory

## System Requirements

**Minimum:**
- Python 3.8+
- 4GB RAM
- 2GB disk space

**Recommended:**
- Python 3.10+
- 16GB RAM
- NVIDIA GPU with 6GB+ VRAM
- 10GB free disk space

## License

This project uses:
- **Whisper**: MIT License (OpenAI)
- **PyAnnote**: MIT License
- **Other dependencies**: Various open source licenses

See the LICENSE files of the individual dependencies for full details.
