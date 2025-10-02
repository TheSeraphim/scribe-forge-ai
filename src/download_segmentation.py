from huggingface_hub import snapshot_download


snapshot_download(
    repo_id="pyannote/segmentation-3.0",
    local_dir="D:/py-audio-transcribe-claude/segmentation-3.0",
    local_dir_use_symlinks=False,
    resume_download=True
)
