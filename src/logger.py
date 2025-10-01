"""
Logging utilities for the transcription system with optional ANSI colors
"""

import logging
import os
import sys
import time
from typing import Optional
import shutil
import textwrap

try:
    from colorama import Fore, Style, init as colorama_init  # type: ignore
except Exception:  # colorama optional at import time
    Fore = Style = None  # type: ignore
    def colorama_init(*args, **kwargs):  # type: ignore
        return None


_T0 = time.perf_counter()

def _format_elapsed(t0: float, t1: float) -> str:
    """Return fixed-width elapsed: [+HHH:MM:SS] or [+HHH:MM:SS.mmm] if LOG_MS=1."""
    ms = os.getenv("LOG_MS") == "1"
    delta = max(0.0, float(t1 - t0))
    total = int(delta)
    h = total // 3600
    m = (total % 3600) // 60
    s = total % 60
    if ms:
        millis = int(round((delta - total) * 1000)) % 1000
        return f"[+{h:03d}:{m:02d}:{s:02d}.{millis:03d}]"
    return f"[+{h:03d}:{m:02d}:{s:02d}]"

class ColorTimestampFormatter(logging.Formatter):
    """Formatter with fixed-width elapsed prefix and optional colored levelnames."""

    LEVEL_COLORS = {
        "DEBUG": "CYAN",
        "INFO": "GREEN",
        "WARNING": "YELLOW",
        "ERROR": "RED",
        "CRITICAL": "MAGENTA",
    }

    def __init__(self, fmt: str, datefmt: Optional[str] = None, use_color: bool = False):
        super().__init__(fmt=fmt, datefmt=datefmt)
        self.use_color = use_color and (Fore is not None and Style is not None)

    def format(self, record):
        elapsed = _format_elapsed(_T0, time.perf_counter())

        # Build a PLAIN (uncolored) padded level for width math
        original_level = record.levelname
        padded_level_plain = (original_level + "       ")[:7]

        # Compose base strings used for indentation math
        # Full first-line prefix including the dash and trailing space
        first_line_prefix = f"{elapsed} {padded_level_plain} - "
        # Continuation indent: spaces up to message start (no dash)
        indent_spaces = " " * len(first_line_prefix)

        # Prepare wrapped message respecting terminal width
        try:
            cols = shutil.get_terminal_size((100, 24)).columns
        except Exception:
            cols = 100
        # Prefix includes: elapsed + space + level(7) + space + dash-space
        prefix_plain = first_line_prefix
        text_width = max(20, cols - len(first_line_prefix))

        original_msg = record.getMessage()
        paragraphs = original_msg.split("\n")
        wrapped_lines: list[str] = []
        for idx, para in enumerate(paragraphs):
            if idx == 0:
                # Wrap first paragraph for the first line
                chunks = textwrap.wrap(
                    para,
                    width=text_width,
                    break_long_words=False,
                    break_on_hyphens=False,
                    replace_whitespace=False,
                ) or [para]
                wrapped_lines.append(chunks[0])
                for cont in chunks[1:]:
                    wrapped_lines.append(indent_spaces + cont)
            else:
                # Subsequent paragraphs: bullet rule only if the raw paragraph begins with exactly two spaces
                is_bullet = para.startswith("  ") and (len(para) == 2 or para[2] != " ")
                content = para.lstrip() if is_bullet else para
                chunks = textwrap.wrap(
                    content,
                    width=text_width,
                    break_long_words=False,
                    break_on_hyphens=False,
                    replace_whitespace=False,
                ) or [content]
                for j, cont in enumerate(chunks):
                    if is_bullet and j == 0:
                        wrapped_lines.append(indent_spaces + "- " + cont)
                    else:
                        wrapped_lines.append(indent_spaces + cont)

        wrapped_message = "\n".join(wrapped_lines)

        # Now render with optional color on the LEVEL only
        try:
            if self.use_color:
                color_name = self.LEVEL_COLORS.get(original_level, None)
                if color_name:
                    color = getattr(Fore, color_name, "")
                    record.levelname = f"{Style.BRIGHT}{color}{padded_level_plain}{Style.RESET_ALL}"
                else:
                    record.levelname = padded_level_plain
            else:
                record.levelname = padded_level_plain

            # Temporarily replace the message for formatting
            msg_backup, args_backup = record.msg, record.args
            record.msg, record.args = wrapped_message, ()
            rendered = super().format(record)  # "<LEVEL7 or colored> - <wrapped_message>"
            record.msg, record.args = msg_backup, args_backup
        finally:
            record.levelname = original_level

        return f"{elapsed} {rendered}"


def setup_logger(log_level="INFO"):
    """Setup logger with ANSI colors when appropriate (TTY and NO_COLOR not set)."""

    logger = logging.getLogger("transcription")
    logger.setLevel(getattr(logging, log_level))
    logger.handlers.clear()

    # Select output stream: default to stderr to avoid interfering with tqdm progress on stdout
    stream_name = os.getenv("LOG_STREAM", "stderr").lower()
    stream = sys.stderr if stream_name != "stdout" else sys.stdout
    console_handler = logging.StreamHandler(stream)
    console_handler.setLevel(getattr(logging, log_level))

    # Determine if colors should be enabled
    no_color = os.getenv("NO_COLOR") == "1"
    is_tty = hasattr(stream, "isatty") and stream.isatty()
    use_color = is_tty and (not no_color)

    # Initialize colorama on Windows for ANSI support
    if use_color:
        try:
            colorama_init()
        except Exception:
            use_color = False

    formatter = ColorTimestampFormatter(
        fmt="%(levelname)s - %(message)s",
        datefmt="%Y%m%d-%H%M%S",
        use_color=use_color,
    )
    console_handler.setFormatter(formatter)

    logger.addHandler(console_handler)
    # Route Python warnings (warnings.warn / DeprecationWarning / UserWarning) into logging
    try:
        import logging as _logging  # local alias
        _logging.captureWarnings(True)
        # Ensure 'py.warnings' messages go through our console handler
        pywarn_logger = _logging.getLogger("py.warnings")
        pywarn_logger.setLevel(_logging.WARNING)
        # Avoid duplicate handlers
        if not any(isinstance(h, type(console_handler)) for h in pywarn_logger.handlers):
            pywarn_logger.addHandler(console_handler)
        pywarn_logger.propagate = False
    except Exception:
        pass
    logger.propagate = False
    return logger
