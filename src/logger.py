"""
Logging utilities for the transcription system
"""

import logging
import sys
from datetime import datetime


class TimestampFormatter(logging.Formatter):
    """Custom formatter with timestamp prefix"""
    
    def format(self, record):
        # Create timestamp in format [yyyyMMdd-HHmmss]
        timestamp = datetime.now().strftime("[%Y%m%d-%H%M%S]")
        
        # Format the original message
        original_format = super().format(record)
        
        # Add timestamp prefix
        return f"{timestamp} {original_format}"


def setup_logger(log_level="INFO"):
    """Setup logger with custom formatting"""
    
    # Create logger
    logger = logging.getLogger("transcription")
    logger.setLevel(getattr(logging, log_level))
    
    # Clear any existing handlers
    logger.handlers.clear()
    
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level))
    
    # Create formatter
    formatter = TimestampFormatter(
        fmt="%(levelname)s - %(message)s"
    )
    console_handler.setFormatter(formatter)
    
    # Add handler to logger
    logger.addHandler(console_handler)
    
    # Prevent propagation to root logger
    logger.propagate = False
    
    return logger
