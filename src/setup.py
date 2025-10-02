#!/usr/bin/env python3
"""
Setup script for Audio Transcription Tool
"""

from setuptools import setup, find_packages
import os

# Read README for long description
with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

# Read requirements
req_path = "docs/requirements.txt" if os.path.exists("docs/requirements.txt") else "requirements.txt"
with open(req_path, "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="audio-transcription-tool",
    version="1.0.0",
    author="Audio Transcription Team",
    description="Complete audio transcription tool with speaker diarization",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/audio-transcription-tool",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Multimedia :: Sound/Audio :: Speech",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    python_requires=">=3.8",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "audio-transcribe=main:main",
        ],
    },
    include_package_data=True,
    zip_safe=False,
)
