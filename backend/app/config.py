from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


@dataclass(frozen=True)
class Settings:
    project_id: str
    calendar_id: str
    cors_origins: tuple[str, ...]
    timezone: str


@lru_cache
def settings() -> Settings:
    origins = tuple(
        item.strip()
        for item in os.getenv("CORS_ORIGINS", "").split(",")
        if item.strip()
    )
    return Settings(
        project_id=os.getenv("GOOGLE_CLOUD_PROJECT", "salon-booking-demo"),
        calendar_id=os.getenv("GOOGLE_CALENDAR_ID", ""),
        cors_origins=origins,
        timezone=os.getenv("APP_TIMEZONE", "Europe/Rome"),
    )
