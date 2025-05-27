# Audio Transcription Tool - Docker Container
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create directories for models and temp files
RUN mkdir -p models temp

# Download basic Whisper model
RUN python -c "import whisper; whisper.load_model('base')"

# Set environment variables
ENV PYTHONPATH=/app
ENV HUGGINGFACE_HUB_CACHE=/app/models/huggingface

# Create non-root user for security
RUN useradd -m -u 1000 transcriber && \
    chown -R transcriber:transcriber /app
USER transcriber

# Expose volume for input/output files
VOLUME ["/data"]

# Set entrypoint
ENTRYPOINT ["python", "main.py"]
CMD ["--help"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import whisper; print('OK')" || exit 1

# Labels
LABEL maintainer="Audio Transcription Team"
LABEL description="Audio transcription tool with speaker diarization"
LABEL version="1.0.0"
