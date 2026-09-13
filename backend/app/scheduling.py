from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from .errors import bad_request, failed_precondition

LOCK_BUCKET_MINUTES = 5
BUCKET_SECONDS = LOCK_BUCKET_MINUTES * 60
DAY_KEYS = (
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
)


DEFAULT_OPENING_HOURS: dict[str, dict[str, Any]] = {
    "monday": {"enabled": True, "open": "09:00", "close": "18:00", "breaks": []},
    "tuesday": {"enabled": True, "open": "09:00", "close": "18:00", "breaks": []},
    "wednesday": {"enabled": True, "open": "09:00", "close": "18:00", "breaks": []},
    "thursday": {"enabled": True, "open": "09:00", "close": "18:00", "breaks": []},
    "friday": {"enabled": True, "open": "09:00", "close": "18:00", "breaks": []},
    "saturday": {"enabled": True, "open": "09:00", "close": "13:00", "breaks": []},
    "sunday": {"enabled": False, "open": "09:00", "close": "18:00", "breaks": []},
}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise bad_request("INVALID_DATE")
    return value.astimezone(timezone.utc)


def bounded_setting(value: Any, fallback: int, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        return fallback
    return value if minimum <= value <= maximum else fallback


def _minutes(value: str) -> int:
    try:
        hours, minutes = (int(part) for part in value.split(":"))
    except (TypeError, ValueError) as error:
        raise failed_precondition("INVALID_OPENING_HOURS") from error
    if not 0 <= hours <= 23 or not 0 <= minutes <= 59:
        raise failed_precondition("INVALID_OPENING_HOURS")
    return hours * 60 + minutes


def opening_day(
    start_at: datetime, config: dict[str, Any]
) -> tuple[datetime, dict[str, Any]]:
    zone = ZoneInfo(config.get("timezone") or "Europe/Rome")
    local_start = aware_utc(start_at).astimezone(zone)
    hours = config.get("openingHours") or DEFAULT_OPENING_HOURS
    key = DAY_KEYS[local_start.weekday()]
    return local_start, hours.get(key, DEFAULT_OPENING_HOURS[key])


def ensure_within_opening_hours(
    start_at: datetime,
    end_with_buffer_at: datetime,
    config: dict[str, Any],
) -> None:
    local_start, day = opening_day(start_at, config)
    local_end = aware_utc(end_with_buffer_at).astimezone(local_start.tzinfo)
    if not day.get("enabled") or local_start.date() != local_end.date():
        raise failed_precondition("OUTSIDE_OPENING_HOURS")
    start_minute = local_start.hour * 60 + local_start.minute
    end_minute = local_end.hour * 60 + local_end.minute
    if start_minute < _minutes(day["open"]) or end_minute > _minutes(day["close"]):
        raise failed_precondition("OUTSIDE_OPENING_HOURS")
    for pause in day.get("breaks", []):
        if start_minute < _minutes(pause["end"]) and end_minute > _minutes(
            pause["start"]
        ):
            raise failed_precondition("OVERLAPS_BREAK")


def local_day_bounds(day: date, timezone_name: str) -> tuple[datetime, datetime]:
    zone = ZoneInfo(timezone_name)
    start = datetime.combine(day, time.min, zone)
    end = datetime.combine(day + timedelta(days=1), time.min, zone)
    return start, end


def lock_bucket_ids(start_at: datetime, end_at: datetime) -> list[str]:
    start = int(aware_utc(start_at).timestamp())
    end = int(aware_utc(end_at).timestamp())
    if end <= start:
        raise bad_request("INVALID_INTERVAL")
    cursor = start // BUCKET_SECONDS * BUCKET_SECONDS
    result: list[str] = []
    while cursor < end:
        result.append(str(cursor // BUCKET_SECONDS).zfill(12))
        cursor += BUCKET_SECONDS
    return result


def slots_for_day(
    day: date,
    service: dict[str, Any],
    config: dict[str, Any],
    now: datetime | None = None,
) -> list[dict[str, str]]:
    zone_name = config.get("timezone") or "Europe/Rome"
    zone = ZoneInfo(zone_name)
    current_utc = aware_utc(now or utc_now())
    current = current_utc.astimezone(zone)
    start, _end = local_day_bounds(day, zone_name)
    horizon = bounded_setting(config.get("bookingHorizonDays"), 90, 1, 730)
    if start.date() < current.date() or start.date() >= current.date() + timedelta(
        days=horizon + 1
    ):
        raise bad_request("DATE_OUT_OF_RANGE")
    hours = config.get("openingHours") or DEFAULT_OPENING_HOURS
    opening = hours.get(
        DAY_KEYS[start.weekday()], DEFAULT_OPENING_HOURS[DAY_KEYS[start.weekday()]]
    )
    if not opening.get("enabled"):
        return []
    open_minutes = _minutes(opening["open"])
    close_minutes = _minutes(opening["close"])
    cursor = start + timedelta(minutes=open_minutes)
    close = start + timedelta(minutes=close_minutes)
    slot_minutes = bounded_setting(config.get("slotMinutes"), 30, 5, 120)
    lead = bounded_setting(config.get("minimumLeadMinutes"), 120, 0, 43_200)
    duration = int(service["durationMinutes"])
    buffer_minutes = int(service.get("bufferMinutes") or 0)
    result: list[dict[str, str]] = []
    while cursor < close:
        service_end = cursor + timedelta(minutes=duration)
        lock_end = service_end + timedelta(minutes=buffer_minutes)
        if lock_end <= close and cursor.astimezone(
            timezone.utc
        ) >= current_utc + timedelta(minutes=lead):
            try:
                ensure_within_opening_hours(cursor, lock_end, config)
            except Exception:
                pass
            else:
                result.append(
                    {
                        "startAt": cursor.astimezone(timezone.utc)
                        .isoformat()
                        .replace("+00:00", "Z"),
                        "endAt": service_end.astimezone(timezone.utc)
                        .isoformat()
                        .replace("+00:00", "Z"),
                    }
                )
        cursor += timedelta(minutes=slot_minutes)
    return result
