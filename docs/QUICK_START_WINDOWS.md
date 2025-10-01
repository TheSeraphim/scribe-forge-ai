# Quick Start Guide (Windows)

## Installation

1. **Open PowerShell as Administrator** (right-click PowerShell → Run as Administrator)

2. **Run the installer:**
   ```powershell
   .\install.ps1
   ```

3. **Follow the prompts** to:
   - Install Python dependencies
   - Download Whisper models (optional)
   - Configure HuggingFace token for speaker diarization (optional)

## Basic Usage

### Simple Transcription

```powershell
.\run.ps1 audio.mp3 -o output --format txt
```

This will:
- Transcribe `audio.mp3` using the base Whisper model
- Save output to `output.txt`
- Use auto-detected language

### With Speaker Diarization

```powershell
.\run.ps1 interview.mp3 -o output --format md --diarize
```

This will:
- Transcribe and identify different speakers
- Save output in Markdown format with speaker labels
- Create `output.md`

### High-Quality Transcription

```powershell
.\run.ps1 lecture.m4a -o output --format json --model-size large-v3 --clean-audio
```

This will:
- Use the highest quality Whisper model (large-v3)
- Apply audio cleaning for better quality
- Save detailed output with timestamps in JSON format

### With Specific Language

```powershell
.\run.ps1 podcast.mp3 -o output --language it --format txt
```

This will:
- Transcribe Italian audio
- Skip auto-detection (faster)
- Save as plain text

## Common Options

| Option | Values | Description |
|--------|--------|-------------|
| `-o`, `--output` | path | Output file path (required) |
| `--format` | `txt`, `json`, `md` | Output format (default: txt) |
| `--model-size` | `tiny`, `base`, `small`, `medium`, `large-v3` | Whisper model size (default: base) |
| `--language` | `en`, `it`, `es`, etc. | Language code (auto-detect if omitted) |
| `--diarize` | flag | Enable speaker diarization |
| `--clean-audio` | flag | Apply audio cleaning |
| `--device` | `auto`, `cpu`, `cuda` | Processing device (default: auto) |
| `-y`, `--assume-yes` | flag | Skip confirmations |
| `--log-level` | `DEBUG`, `INFO`, `WARNING`, `ERROR` | Logging detail level |

## File Paths with Spaces

**Always quote paths containing spaces:**

```powershell
# ✅ Correct
.\run.ps1 "My Recording.mp3" -o "My Documents\output" --format txt

# ❌ Wrong - will fail
.\run.ps1 My Recording.mp3 -o My Documents\output --format txt
```

## Model Sizes

| Model | Size | Speed | Quality | VRAM |
|-------|------|-------|---------|------|
| `tiny` | 39MB | ~32x realtime | Basic | ~1GB |
| `base` | 74MB | ~16x realtime | Good | ~1GB |
| `small` | 244MB | ~6x realtime | Very Good | ~2GB |
| `medium` | 769MB | ~2x realtime | Excellent | ~5GB |
| `large-v3` | 1.5GB | ~1x realtime | Best | ~10GB |

**Recommendation:**
- **Quick testing:** `tiny` or `base`
- **Production use:** `small` or `medium`
- **Maximum accuracy:** `large-v3` (requires good GPU)

## Output Formats

### TXT (Plain Text)
```powershell
.\run.ps1 audio.mp3 -o output --format txt
```
- Human-readable format
- Timestamps in `[HH:MM:SS]` format
- Speaker labels (if diarization enabled)
- Full transcription at the end

### JSON (Structured Data)
```powershell
.\run.ps1 audio.mp3 -o output --format json
```
- Complete structured data
- Word-level timestamps
- Confidence scores
- Metadata (language, duration, etc.)
- Best for programmatic processing

### MD (Markdown)
```powershell
.\run.ps1 audio.mp3 -o output --format md
```
- Formatted text with headers
- Organized by speaker sections
- Easy to read and share
- Great for documentation

## Getting Help

```powershell
.\run.ps1 --help
```

Shows all available options with descriptions.

## Examples

### 1. Transcribe a Meeting Recording
```powershell
.\run.ps1 "Team Meeting 2024-10-01.m4a" -o "Meetings\2024-10-01" --format md --diarize --clean-audio
```

### 2. Quick Transcription Test
```powershell
.\run.ps1 sample.wav -o test --format txt --model-size tiny -y
```

### 3. High-Quality Italian Podcast
```powershell
.\run.ps1 podcast_ep5.mp3 -o "Transcripts\Episode 5" --language it --format json --model-size large-v3 --device cuda
```

### 4. Batch Processing (Loop)
```powershell
Get-ChildItem *.mp3 | ForEach-Object {
    .\run.ps1 $_.FullName -o "output\$($_.BaseName)" --format txt -y
}
```

## Troubleshooting

### Error: "Virtual environment not found"
**Solution:** Run `.\install.ps1` first

### Error: "CUDA requested but not available"
**Solution:** Either:
- Add `-y` flag to use CPU instead
- Or change `--device cuda` to `--device cpu`

### Error: "Speaker diarization requested but not available"
**Solution:**
1. Configure HuggingFace token: `.\install.ps1 -HuggingFaceToken "your_token"`
2. Or add `-y` flag to skip diarization

### Slow Processing
**Solutions:**
- Use smaller model: `--model-size tiny` or `--model-size base`
- Use GPU if available: `--device cuda`
- Skip audio cleaning: remove `--clean-audio`

### Poor Transcription Quality
**Solutions:**
- Use larger model: `--model-size large-v3`
- Enable audio cleaning: `--clean-audio`
- Specify language: `--language en` (skip auto-detection)

## Advanced Usage

### Custom Output Directory
```powershell
.\run.ps1 audio.mp3 -o "C:\Users\YourName\Documents\Transcripts\output" --format txt --create-output-dir
```

### Download Models in Advance
```powershell
.\install.ps1 -DownloadModels -DownloadDiarizationModels
```

### Force CPU (No GPU)
```powershell
.\run.ps1 audio.mp3 -o output --device cpu --format txt
```

### Verbose Logging
```powershell
.\run.ps1 audio.mp3 -o output --log-level DEBUG --format txt
```

## Tips

1. **Test with `tiny` model first** - verify everything works before using larger models
2. **Use `--diarize` for multi-speaker audio** - meetings, interviews, podcasts
3. **GPU acceleration helps** - but only with `medium` and `large` models
4. **Specify language when known** - saves time and improves accuracy
5. **Use `--clean-audio` for noisy recordings** - phone calls, outdoor recordings
6. **Markdown format is great for sharing** - easily readable and formatted

## Need More Help?

- View detailed documentation: See `README.md`
- Check parameter verification: See `RUN_PS1_VERIFICATION.md`
- Review installation guide: See `windows_install_guide.md`
- Run tests: `.\test-run-ps1.ps1`

## System Requirements

- **Windows 10/11** with PowerShell 5.1+
- **Python 3.8+** (3.11 or 3.12 recommended)
- **8GB RAM minimum** (16GB+ recommended for large models)
- **GPU (optional):** NVIDIA with CUDA support for faster processing
- **Storage:** 2-10GB depending on models downloaded

## What Gets Installed

- Virtual environment (`.venv` folder)
- Whisper models (`models/` folder) - downloaded on first use
- Python packages:
  - openai-whisper or faster-whisper (transcription)
  - resemblyzer (speaker diarization, Python 3.12+)
  - pyannote.audio (alternative diarization, Python ≤3.11)
  - librosa, soundfile (audio processing)
  - torch (AI/ML framework)

## Keeping It Updated

```powershell
# Update Python packages
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade -r requirements.txt
```

## Uninstalling

```powershell
# Remove virtual environment
Remove-Item .venv -Recurse -Force

# Remove downloaded models
Remove-Item models -Recurse -Force

# Remove temporary files
Remove-Item temp -Recurse -Force
```

---

**Quick Reference Card:**
```powershell
# Basic:           .\run.ps1 audio.mp3 -o output --format txt
# With speakers:   .\run.ps1 audio.mp3 -o output --diarize --format md
# High quality:    .\run.ps1 audio.mp3 -o output --model-size large-v3 --clean-audio
# Help:            .\run.ps1 --help
```
