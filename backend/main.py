"""ASGI entrypoint for hosting platforms that auto-detect ``main.py``."""

from app.main import app

__all__ = ["app"]
