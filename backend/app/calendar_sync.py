from __future__ import annotations

import logging
from datetime import datetime
from hashlib import sha256
from typing import Any

import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from pymongo.database import Database

from .config import settings
from .scheduling import aware_utc, utc_now

logger = logging.getLogger(__name__)


def _event_id(appointment_id: str) -> str:
    return sha256(appointment_id.encode("utf-8")).hexdigest()[:64]


def _service() -> Any:
    credentials, _project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/calendar"]
    )
    return build("calendar", "v3", credentials=credentials, cache_discovery=False)


def sync_event(
    db: Database[dict[str, Any]],
    appointment_id: str,
    appointment: dict[str, Any],
) -> None:
    calendar_id = settings().calendar_id
    if not calendar_id:
        db.appointments.update_one(
            {"_id": appointment_id},
            {
                "$set": {
                    "calendarSyncStatus": "NOT_CONFIGURED",
                    "calendarSyncAt": utc_now(),
                }
            },
        )
        return
    start = appointment.get("confirmedStartAt")
    end = appointment.get("confirmedEndAt")
    if not isinstance(start, datetime) or not isinstance(end, datetime):
        return
    event_id = appointment.get("googleCalendarEventId") or _event_id(appointment_id)
    body = {
        "summary": f"{appointment.get('serviceName', 'Servizio')} - {appointment.get('clientName', 'Cliente')}",
        "description": "\n".join(
            item
            for item in (
                f"Cliente: {appointment.get('clientName', 'Cliente')}",
                f"Telefono: {appointment['clientPhone']}"
                if appointment.get("clientPhone")
                else "",
                f"Servizio: {appointment.get('serviceName', '')}",
                f"ID appuntamento: {appointment_id}",
            )
            if item
        ),
        "start": {"dateTime": aware_utc(start).isoformat(), "timeZone": "Europe/Rome"},
        "end": {"dateTime": aware_utc(end).isoformat(), "timeZone": "Europe/Rome"},
        "extendedProperties": {"private": {"appointmentId": appointment_id}},
    }
    try:
        service = _service()
        try:
            service.events().update(
                calendarId=calendar_id, eventId=event_id, body=body
            ).execute()
        except HttpError as error:
            if error.resp.status != 404:
                raise
            try:
                service.events().insert(
                    calendarId=calendar_id, body={"id": event_id, **body}
                ).execute()
            except HttpError as insert_error:
                if insert_error.resp.status != 409:
                    raise
                service.events().update(
                    calendarId=calendar_id, eventId=event_id, body=body
                ).execute()
        db.appointments.update_one(
            {"_id": appointment_id},
            {
                "$set": {
                    "googleCalendarEventId": event_id,
                    "calendarSyncStatus": "SYNCED",
                    "calendarSyncAt": utc_now(),
                }
            },
        )
    except Exception as error:
        logger.exception("Google Calendar sync failed for %s", appointment_id)
        db.appointments.update_one(
            {"_id": appointment_id},
            {
                "$set": {
                    "calendarSyncStatus": "ERROR",
                    "calendarSyncError": str(error)[:500],
                    "calendarSyncAt": utc_now(),
                }
            },
        )


def delete_event(
    db: Database[dict[str, Any]],
    appointment_id: str,
    appointment: dict[str, Any],
) -> None:
    if not settings().calendar_id:
        return
    event_id = appointment.get("googleCalendarEventId") or _event_id(appointment_id)
    try:
        _service().events().delete(
            calendarId=settings().calendar_id, eventId=event_id
        ).execute()
    except HttpError as error:
        if error.resp.status not in {404, 410}:
            logger.exception("Google Calendar delete failed for %s", appointment_id)
            return
    db.appointments.update_one(
        {"_id": appointment_id},
        {"$set": {"calendarSyncStatus": "DELETED", "calendarSyncAt": utc_now()}},
    )
