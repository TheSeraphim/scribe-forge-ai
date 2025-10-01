<#
.SYNOPSIS
  Non-interactive smoke checks for environment readiness.
.DESCRIPTION
  Prints torch version and device, verifies whisper tiny load, resemblyzer import,
  and conditionally imports pyannote Pipeline on Python <=3.11 when HF token present.
#>

$ErrorActionPreference = "Stop"

try {
  $torchInfo = python - << 'PY'
import torch, json
print(json.dumps({
  "version": torch.__version__,
  "cuda_available": torch.cuda.is_available(),
}))
PY
  Write-Host "torch: $torchInfo"
} catch { Write-Host "torch import failed: $_" -ForegroundColor Yellow }

try {
  $w = python - << 'PY'
import whisper
whisper.load_model("tiny")
print("whisper tiny ok")
PY
  Write-Host $w
} catch { Write-Host "whisper load failed: $_" -ForegroundColor Yellow }

try {
  $r = python - << 'PY'
import importlib
print("resemblyzer ok" if importlib.util.find_spec("resemblyzer") else "resemblyzer missing")
PY
  Write-Host $r
} catch { Write-Host "resemblyzer check failed: $_" -ForegroundColor Yellow }

try {
  $p = python - << 'PY'
import os, sys
hf = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
if sys.version_info[:2] <= (3,11) and hf:
    from pyannote.audio import Pipeline
    print("pyannote import ok")
else:
    print("pyannote skipped")
PY
  Write-Host $p
} catch { Write-Host "pyannote check failed: $_" -ForegroundColor Yellow }

Write-Host "Smoke complete"

