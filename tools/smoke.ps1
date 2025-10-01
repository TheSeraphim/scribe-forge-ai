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
try:
    import resemblyzer  # noqa: F401
    print("resemblyzer ok")
except Exception as e:
    print(f"resemblyzer missing: {e}")
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

# CUDA diagnostic (machine-readable JSON line + optional WARN)
Write-Host "Running CUDA diagnostic" -ForegroundColor Cyan
try {
  $cudaDiagOutput = python - << 'PY'
import json, subprocess, shutil
info = {"torch": None, "torch_cuda_built": None, "torch_cuda_version": None,
        "cuda_is_available": None, "device": None, "nvidia_smi": None}
try:
    import torch
    info["torch"] = getattr(torch, "__version__", "?")
    info["torch_cuda_built"] = getattr(getattr(torch, "backends", None), "cuda", None)
    if info["torch_cuda_built"] is not None:
        info["torch_cuda_built"] = bool(getattr(info["torch_cuda_built"], "is_built", lambda: False)())
    info["torch_cuda_version"] = getattr(getattr(torch, "version", None), "cuda", None)
    try:
        info["cuda_is_available"] = bool(torch.cuda.is_available())
        if info["cuda_is_available"]:
            info["device"] = torch.cuda.get_device_name(0)
    except Exception as e:
        info["cuda_is_available"] = False
except Exception as e:
    info["error"] = f"torch import failed: {e}"
if shutil.which("nvidia-smi"):
    try:
        out = subprocess.check_output(["nvidia-smi", "--query-gpu=driver_version,name", "--format=csv,noheader"], text=True)
        info["nvidia_smi"] = out.strip()
    except Exception as e:
        info["nvidia_smi"] = f"error: {e}"
print("CUDA_DIAG "+json.dumps(info))
PY
  if ($cudaDiagOutput) { Write-Host $cudaDiagOutput }
  try {
    $line = ($cudaDiagOutput -split "`n") | Where-Object { $_ -like 'CUDA_DIAG *' } | Select-Object -First 1
    if ($line) {
      $obj = $line.Substring(10) | ConvertFrom-Json
      if ($obj -and $obj.torch_cuda_built -eq $true -and ($obj.cuda_is_available -ne $true)) {
        Write-Host "WARN torch CUDA built but unavailable; typical causes: outdated driver vs cu124, WSL without GPU, or permissions. Falling back to CPU." -ForegroundColor Yellow
      }
    }
  } catch {}
} catch { Write-Host "CUDA diagnostic failed: $_" -ForegroundColor Yellow }
