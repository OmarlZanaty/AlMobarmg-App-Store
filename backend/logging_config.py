from __future__ import annotations

import logging
from typing import Any


def get_logging_config() -> dict[str, Any]:
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
                "datefmt": "%Y-%m-%dT%H:%M:%S%z",
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "standard",
            }
        },
        "root": {
            "handlers": ["console"],
            "level": "INFO",
        },
        "loggers": {
            "uvicorn": {"level": "WARNING", "handlers": ["console"], "propagate": False},
            "uvicorn.error": {"level": "WARNING", "handlers": ["console"], "propagate": False},
            "uvicorn.access": {"level": "WARNING", "handlers": ["console"], "propagate": False},
            "sqlalchemy.engine": {"level": "WARNING", "handlers": ["console"], "propagate": False},
            "celery": {"level": "INFO", "handlers": ["console"], "propagate": False},
        },
    }


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
