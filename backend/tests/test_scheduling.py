from datetime import date, datetime, timezone

import pytest

from app.errors import ApiError
from app.scheduling import (
    ensure_within_opening_hours,
    local_day_bounds,
    lock_bucket_ids,
    slots_for_day,
)


def test_overlapping_intervals_share_a_lock_bucket() -> None:
    first = lock_bucket_ids(
        datetime(2026, 9, 1, 8, 0, tzinfo=timezone.utc),
        datetime(2026, 9, 1, 8, 35, tzinfo=timezone.utc),
    )
    second = lock_bucket_ids(
        datetime(2026, 9, 1, 8, 30, tzinfo=timezone.utc),
        datetime(2026, 9, 1, 9, 0, tzinfo=timezone.utc),
    )
    assert set(first) & set(second)


def test_daylight_saving_days_have_correct_length() -> None:
    short_start, short_end = local_day_bounds(date(2026, 3, 29), "Europe/Rome")
    long_start, long_end = local_day_bounds(date(2026, 10, 25), "Europe/Rome")
    assert (
        short_end.astimezone(timezone.utc) - short_start.astimezone(timezone.utc)
    ).total_seconds() == 23 * 3600
    assert (
        long_end.astimezone(timezone.utc) - long_start.astimezone(timezone.utc)
    ).total_seconds() == 25 * 3600


def test_break_is_not_bookable() -> None:
    config = {
        "timezone": "Europe/Rome",
        "openingHours": {
            "monday": {
                "enabled": True,
                "open": "09:00",
                "close": "18:00",
                "breaks": [{"start": "12:30", "end": "14:00"}],
            }
        },
    }
    with pytest.raises(ApiError) as error:
        ensure_within_opening_hours(
            datetime.fromisoformat("2026-08-31T12:15:00+02:00"),
            datetime.fromisoformat("2026-08-31T12:45:00+02:00"),
            config,
        )
    assert error.value.message == "OVERLAPS_BREAK"


def test_availability_does_not_hide_busy_slots() -> None:
    slots = slots_for_day(
        date(2026, 9, 7),
        {"durationMinutes": 30, "bufferMinutes": 0},
        {
            "timezone": "Europe/Rome",
            "minimumLeadMinutes": 0,
            "bookingHorizonDays": 90,
            "slotMinutes": 30,
        },
        now=datetime(2026, 9, 6, 8, 0, tzinfo=timezone.utc),
    )
    assert slots[0]["startAt"] == "2026-09-07T07:00:00Z"
    assert len(slots) == 18
