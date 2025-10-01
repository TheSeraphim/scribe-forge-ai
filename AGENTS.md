# Repository Guidelines

## Project Structure & Module Organization
- Entry point: `main.py` (CLI orchestration, logging, error handling).
- Core modules in `src/`: `audio_processor.py`, `model_manager.py`, `transcriber.py`, `diarizer.py`, `output_formatter.py`, `logger.py`.
- Examples: `examples/usage_examples.py` (end‑to‑end runs). Large assets and models live in `models/` and are git‑ignored. Optional I/O under `data/`.
- Automation: `Makefile` targets; containerization via `Dockerfile` and `docker-compose.yml`.

## Build, Test, and Development Commands
- `make help`: Show available targets.
- `make setup`: Create `venv/` and print activation tips.
- `make install-dev`: Install deps + dev tools (`black`, `flake8`, `pytest`, `mypy`).
- `make format` / `make lint`: Apply Black (100 cols) and run Flake8/Mypy.
- `make test`: Run `pytest` (expects tests in `tests/`) and examples.
- `python main.py input.m4a -o out --format md --diarize`: Local run example.
- Docker: `make docker-build` then `make docker-run` (mounts `./data`).

## Coding Style & Naming Conventions
- Python 3.x, 4‑space indentation, PEP8. Format with Black (`--line-length 100`).
- Lint with Flake8 (ignore `E203`, `W503`); type check with Mypy (`--ignore-missing-imports`).
- Naming: modules/files `snake_case.py`; functions/vars `snake_case`; classes `PascalCase`; constants `UPPER_SNAKE`.
- Logging: use `src.logger.setup_logger`; avoid `print`. Prefer `pathlib.Path` for paths.

## Testing Guidelines
- Framework: `pytest`. Place tests in `tests/` as `test_<module>.py` with `test_*` functions.
- Aim to cover new logic (parsing, formatting, error paths). For audio paths, keep tests deterministic; use small fixtures or synthetic WAVs.
- Run: `make test` or `python -m pytest -q`.

## Commit & Pull Request Guidelines
- Commits: concise imperative subject (≤72 chars) with optional body. Recommended prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`.
- PRs: clear description, motivation, and scope; link issues; include CLI examples and before/after notes. Attach logs or screenshots when relevant.
- Quality gate: pass `make format`, `make lint`, and `make test` before requesting review.

## Security & Configuration Tips
- Do not commit large audio, model weights, or secrets (`models/`, `data/`, caches are already ignored).
- Useful env vars: `HUGGINGFACE_HUB_TOKEN`, `CUDA_VISIBLE_DEVICES`, `TRANSFORMERS_CACHE`.
- Prefer downloading models via Make targets or `--download-models` to keep runs reproducible.

