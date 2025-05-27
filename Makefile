# Audio Transcription Tool - Makefile
# Automates common development and deployment tasks

.PHONY: help install test clean docker examples setup-dev lint format

# Default target
help: ## Show this help
	@echo "Audio Transcription Tool - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Installation targets
install: ## Install the project and dependencies
	@echo "Installing Audio Transcription Tool..."
	chmod +x install.sh
	./install.sh

install-dev: ## Install development dependencies
	pip install -r requirements.txt
	pip install black flake8 pytest mypy
	pre-commit install

setup: ## Initial project setup
	python -m venv venv
	@echo "Virtual environment created. Activate with:"
	@echo "source venv/bin/activate  # Linux/macOS"
	@echo "venv\\Scripts\\activate     # Windows"

# Development targets
lint: ## Run code quality checks
	@echo "Running code quality checks..."
	flake8 src/ main.py --max-line-length=100 --ignore=E203,W503
	mypy src/ main.py --ignore-missing-imports

format: ## Format code with black
	@echo "Formatting code with black..."
	black src/ main.py --line-length=100

test: ## Run tests
	@echo "Running tests..."
	python -m pytest tests/ -v
	python examples/usage_examples.py

# Cleaning targets
clean: ## Clean temporary files
	@echo "Cleaning up temporary files..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	rm -rf temp/*
	rm -rf build/
	rm -rf dist/

clean-models: ## Remove downloaded models (free space)
	@echo "Removing downloaded models..."
	rm -rf models/
	@echo "Models removed. They will be re-downloaded on next use."

clean-all: clean clean-models ## Complete cleanup

# Docker targets
docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t audio-transcription:latest .

docker-run: ## Run Docker container (example)
	@echo "Running Docker container..."
	docker run -v $(PWD)/data:/data audio-transcription:latest \
		/data/sample.m4a -o /data/output --format txt

docker-compose-up: ## Start with docker-compose
	docker-compose up --build

docker-clean: ## Clean Docker images
	docker system prune -f
	docker image rm audio-transcription:latest 2>/dev/null || true

# Model management
download-models: ## Download base models
	@echo "Downloading base models..."
	python -c "import whisper; whisper.load_model('base')"
	@echo "Note: For speaker diarization, configure HuggingFace token first"

download-all-models: ## Download all Whisper models
	@echo "Downloading all Whisper models (this will take time and space)..."
	python -c "
import whisper
models = ['tiny', 'base', 'small', 'medium', 'large-v3']
for model in models:
    print(f'Downloading {model}...')
    whisper.load_model(model)
print('All models downloaded!')
"

# Example targets
examples: ## Run usage examples
	@echo "Running usage examples..."
	python examples/usage_examples.py

create-sample: ## Create sample audio file for tests
	@echo "Creating sample audio file..."
	python -c "
import numpy as np
import soundfile as sf
# Generate 10 seconds of sine wave at 440Hz
sample_rate = 16000
duration = 10
t = np.linspace(0, duration, sample_rate * duration)
audio = 0.3 * np.sin(2 * np.pi * 440 * t)
sf.write('data/sample.wav', audio, sample_rate)
print('Sample audio created: data/sample.wav')
"

# Quick transcription targets
transcribe-sample: ## Transcribe sample file
	python main.py data/sample.wav -o data/sample_output --format txt

transcribe-with-speakers: ## Transcribe with diarization
	python main.py data/sample.wav -o data/sample_speakers --format md --diarize

# Performance testing
benchmark: ## Performance benchmark
	@echo "Running performance benchmark..."
	python -c "
import time
import subprocess
import sys

def run_benchmark(model_size, audio_file='data/sample.wav'):
    start_time = time.time()
    try:
        subprocess.run([
            sys.executable, 'main.py', audio_file,
            '-o', f'benchmark_{model_size}',
            '--model-size', model_size,
            '--format', 'txt'
        ], check=True, capture_output=True)
        end_time = time.time()
        return end_time - start_time
    except subprocess.CalledProcessError:
        return None

models = ['tiny', 'base', 'small']
print('Benchmarking transcription speed:')
for model in models:
    duration = run_benchmark(model)
    if duration:
        print(f'{model:6s}: {duration:.2f}s')
    else:
        print(f'{model:6s}: ERROR')
"

# Documentation targets
docs: ## Generate documentation
	@echo "Generating documentation..."
	mkdir -p docs/
	python -c "
import main
import src.transcriber
import src.diarizer
help(main)
" > docs/API.md

# Package targets
package: clean ## Create distributable package
	@echo "Creating distribution package..."
	python setup.py sdist bdist_wheel

install-package: package ## Install from local package
	pip install dist/*.whl

# Quality assurance
check: lint test ## Complete quality checks

pre-commit: format lint ## Pre-commit checks
	@echo "Pre-commit checks completed"

# Environment info
info: ## Show environment information
	@echo "Environment Information:"
	@echo "======================="
	@python --version
	@echo "Python location: $$(which python)"
	@echo "Virtual env: $$VIRTUAL_ENV"
	@echo "Working directory: $$(pwd)"
	@echo ""
	@echo "Installed packages:"
	@pip list | grep -E "(whisper|torch|librosa|pyannote)"

# Help target (repeated for convenience)
.DEFAULT_GOAL := help
