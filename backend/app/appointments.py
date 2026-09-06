from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, Literal
from uuid import uuid4
from zoneinfo import ZoneInfo

from pymongo.database import Database
from pymongo.errors import BulkWriteError, DuplicateKeyError

from .database import session_args, transaction
from .errors import ApiError, bad_request, failed_precondition, forbidden, not_found
from .scheduling import (
    DEFAULT_OPENING_HOURS,
    aware_utc,
    bounded_setting,
    ensure_within_opening_hours,
    lock_bucket_ids,
    slots_for_day,
    utc_now,
)

Appointment = dict[str, Any]


def _config(db: Database[dict[str, Any]]) -> dict[str, Any]:
    return db.studio.find_one({"_id": "config"}) or {
        "timezone": "Europe/Rome",
        "openingHours": DEFAULT_OPENING_HOURS,
    }


def _history(previous: str | None, current: str, actor_id: str) -> dict[str, Any]:
    return {"from": previous, "to": current, "at": utc_now(), "actorId": actor_id}


def rate_limit(
    db: Database[dict[str, Any]],
    subject: str,
    action: str,
    maximum: int,
    window_seconds: int = 60,
) -> None:
    key = f"{subject}_{action}"
    now = utc_now()
    cutoff = now - timedelta(seconds=window_seconds)
    current = db.rate_limits.find_one_and_update(
        {"_id": key, "windowStart": {"$gt": cutoff}, "count": {"$lt": maximum}},
        {
            "$inc": {"count": 1},
            "$set": {"expiresAt": now + timedelta(seconds=window_seconds * 2)},
        },
    )
    if current:
        return
    existing = db.rate_limits.find_one({"_id": key})
    if existing and existing.get("windowStart") and existing["windowStart"] > cutoff:
        raise ApiError(429, "resource-exhausted", "RATE_LIMITED")
    db.rate_limits.update_one(
        {
            "_id": key,
            "$or": [
                {"windowStart": {"$lte": cutoff}},
                {"windowStart": {"$exists": False}},
            ],
        },
        {
            "$set": {
                "windowStart": now,
                "count": 1,
                "expiresAt": now + timedelta(seconds=window_seconds * 2),
            }
        },
        upsert=existing is None,
    )


def availability(
    db: Database[dict[str, Any]], user_id: str, service_id: str, day: date
) -> list[dict[str, str]]:
    rate_limit(db, user_id, "availability", 60)
    service = db.services.find_one({"_id": service_id, "active": True})
    if not service:
        raise not_found("SERVICE_NOT_FOUND")
    return slots_for_day(day, service, _config(db))


def create_request(
    db: Database[dict[str, Any]],
    user: dict[str, Any],
    service_id: str,
    requested_start_at: datetime,
) -> str:
    user_id = str(user["_id"])
    rate_limit(db, user_id, "createAppointment", 10, 3600)
    if user.get("emailVerified") is not True:
        raise failed_precondition("EMAIL_NOT_VERIFIED")
    service = db.services.find_one({"_id": service_id, "active": True})
    if not service:
        raise not_found("SERVICE_NOT_FOUND")
    start_at = aware_utc(requested_start_at)
    config = _config(db)
    lead = bounded_setting(config.get("minimumLeadMinutes"), 120, 0, 43_200)
    if start_at < utc_now() + timedelta(minutes=lead):
        raise bad_request("DATE_TOO_SOON")
    horizon = bounded_setting(config.get("bookingHorizonDays"), 90, 1, 730)
    zone = ZoneInfo(config.get("timezone") or "Europe/Rome")
    if start_at.astimezone(zone).date() > utc_now().astimezone(zone).date() + timedelta(
        days=horizon
    ):
        raise bad_request("DATE_OUT_OF_RANGE")
    duration = int(service["durationMinutes"])
    buffer_minutes = int(service.get("bufferMinutes") or 0)
    end_at = start_at + timedelta(minutes=duration)
    ensure_within_opening_hours(
        start_at,
        end_at + timedelta(minutes=buffer_minutes),
        config,
    )
    appointment_id = str(uuid4())
    now = utc_now()
    client_name = f"{user.get('firstName', '')} {user.get('lastName', '')}".strip()
    db.appointments.insert_one(
        {
            "_id": appointment_id,
            "clientId": user_id,
            "clientName": client_name or "Cliente",
            "clientPhone": user.get("phone"),
            "serviceId": service_id,
            "serviceName": service["name"],
            "durationMinutes": duration,
            "bufferMinutes": buffer_minutes,
            "status": "PENDING_ADMIN",
            "requestedStartAt": start_at,
            "requestedEndAt": end_at,
            "createdAt": now,
            "updatedAt": now,
            "reminderSent": False,
            "history": [_history(None, "PENDING_ADMIN", user_id)],
        }
    )
    return appointment_id


def _lock_documents(
    start_at: datetime, end_at: datetime, holder_id: str
) -> list[dict[str, Any]]:
    now = utc_now()
    return [
        {
            "_id": bucket,
            "holderId": holder_id,
            "holderType": "appointment",
            "updatedAt": now,
        }
        for bucket in lock_bucket_ids(start_at, end_at)
    ]


def _acquire_locks(
    db: Database[dict[str, Any]],
    start_at: datetime,
    end_at: datetime,
    holder_id: str,
    session: Any | None,
) -> None:
    documents = _lock_documents(start_at, end_at, holder_id)
    try:
        db.appointment_locks.insert_many(
            documents, ordered=True, **session_args(session)
        )
    except (BulkWriteError, DuplicateKeyError) as error:
        if session is None:
            db.appointment_locks.delete_many({"holderId": holder_id})
        raise failed_precondition("SLOT_UNAVAILABLE") from error


def _confirm(
    db: Database[dict[str, Any]],
    appointment_id: str,
    candidate: Literal["requested", "proposed"],
    actor_id: str,
    is_admin: bool,
) -> Appointment:
    with transaction() as session:
        appointment = db.appointments.find_one(
            {"_id": appointment_id}, **session_args(session)
        )
        if not appointment:
            raise not_found("APPOINTMENT_NOT_FOUND")
        valid = (
            candidate == "requested" and appointment.get("status") == "PENDING_ADMIN"
            if is_admin
            else appointment.get("clientId") == actor_id
            and candidate == "proposed"
            and appointment.get("status") == "COUNTER_PROPOSED"
        )
        if not valid:
            raise forbidden("INVALID_TRANSITION")
        start_at = appointment.get(
            "requestedStartAt" if candidate == "requested" else "proposedStartAt"
        )
        if not isinstance(start_at, datetime):
            raise failed_precondition("MISSING_PROPOSAL")
        start_at = aware_utc(start_at)
        duration = int(appointment["durationMinutes"])
        buffer_minutes = int(appointment.get("bufferMinutes") or 0)
        end_at = start_at + timedelta(minutes=duration)
        lock_end = end_at + timedelta(minutes=buffer_minutes)
        ensure_within_opening_hours(start_at, lock_end, _config(db))
        _acquire_locks(db, start_at, lock_end, appointment_id, session)
        now = utc_now()
        db.appointments.update_one(
            {"_id": appointment_id, "status": appointment["status"]},
            {
                "$set": {
                    "status": "CONFIRMED",
                    "confirmedStartAt": start_at,
                    "confirmedEndAt": end_at,
                    "confirmedAt": now,
                    "updatedAt": now,
                    "reminderSent": False,
                },
                "$push": {
                    "history": _history(appointment["status"], "CONFIRMED", actor_id)
                },
            },
            **session_args(session),
        )
        return {
            **appointment,
            "status": "CONFIRMED",
            "confirmedStartAt": start_at,
            "confirmedEndAt": end_at,
        }


def admin_accept(
    db: Database[dict[str, Any]], user_id: str, appointment_id: str
) -> Appointment:
    return _confirm(db, appointment_id, "requested", user_id, True)


def admin_reject(
    db: Database[dict[str, Any]], user_id: str, appointment_id: str, reason: str | None
) -> Appointment:
    appointment = db.appointments.find_one({"_id": appointment_id})
    if not appointment:
        raise not_found("APPOINTMENT_NOT_FOUND")
    if appointment.get("status") not in {
        "PENDING_ADMIN",
        "COUNTER_PROPOSED",
        "COUNTER_REJECTED",
    }:
        raise failed_precondition("INVALID_TRANSITION")
    changes: dict[str, Any] = {
        "status": "REJECTED",
        "rejectedAt": utc_now(),
        "updatedAt": utc_now(),
    }
    if reason and reason.strip():
        changes["adminReason"] = reason.strip()
    db.appointments.update_one(
        {"_id": appointment_id, "status": appointment["status"]},
        {
            "$set": changes,
            "$push": {"history": _history(appointment["status"], "REJECTED", user_id)},
        },
    )
    return {**appointment, **changes}


def admin_counter_propose(
    db: Database[dict[str, Any]],
    user_id: str,
    appointment_id: str,
    proposed_start_at: datetime,
) -> Appointment:
    appointment = db.appointments.find_one({"_id": appointment_id})
    if not appointment:
        raise not_found("APPOINTMENT_NOT_FOUND")
    if appointment.get("status") not in {
        "PENDING_ADMIN",
        "COUNTER_PROPOSED",
        "COUNTER_REJECTED",
    }:
        raise failed_precondition("INVALID_TRANSITION")
    proposed_start = aware_utc(proposed_start_at)
    duration = int(appointment["durationMinutes"])
    buffer_minutes = int(appointment.get("bufferMinutes") or 0)
    end_at = proposed_start + timedelta(minutes=duration)
    lock_end = end_at + timedelta(minutes=buffer_minutes)
    ensure_within_opening_hours(proposed_start, lock_end, _config(db))
    if db.appointment_locks.find_one(
        {"_id": {"$in": lock_bucket_ids(proposed_start, lock_end)}}
    ):
        raise failed_precondition("SLOT_UNAVAILABLE")
    changes = {
        "status": "COUNTER_PROPOSED",
        "originalStartAt": appointment.get("originalStartAt")
        or appointment["requestedStartAt"],
        "proposedStartAt": proposed_start,
        "proposedEndAt": end_at,
        "counterProposedAt": utc_now(),
        "counterProposedBy": user_id,
        "updatedAt": utc_now(),
    }
    db.appointments.update_one(
        {"_id": appointment_id, "status": appointment["status"]},
        {
            "$set": changes,
            "$push": {
                "history": _history(appointment["status"], "COUNTER_PROPOSED", user_id)
            },
        },
    )
    return {**appointment, **changes}


def client_counter_response(
    db: Database[dict[str, Any]], user_id: str, appointment_id: str, accept: bool
) -> tuple[str, Appointment]:
    rate_limit(db, user_id, "counterResponse", 10, 3600)
    if accept:
        appointment = _confirm(db, appointment_id, "proposed", user_id, False)
        return "CONFIRMED", appointment
    appointment = db.appointments.find_one({"_id": appointment_id})
    if not appointment:
        raise not_found("APPOINTMENT_NOT_FOUND")
    if (
        appointment.get("clientId") != user_id
        or appointment.get("status") != "COUNTER_PROPOSED"
    ):
        raise forbidden("INVALID_TRANSITION")
    db.appointments.update_one(
        {"_id": appointment_id, "status": "COUNTER_PROPOSED"},
        {
            "$set": {
                "status": "COUNTER_REJECTED",
                "counterRejectedAt": utc_now(),
                "updatedAt": utc_now(),
            },
            "$push": {
                "history": _history("COUNTER_PROPOSED", "COUNTER_REJECTED", user_id)
            },
        },
    )
    return "COUNTER_REJECTED", {**appointment, "status": "COUNTER_REJECTED"}


def cancel(
    db: Database[dict[str, Any]], user: dict[str, Any], appointment_id: str
) -> Appointment:
    user_id = str(user["_id"])
    appointment = db.appointments.find_one({"_id": appointment_id})
    if not appointment:
        raise not_found("APPOINTMENT_NOT_FOUND")
    is_admin = user.get("role") in {"manager", "owner"}
    if not is_admin and appointment.get("clientId") != user_id:
        raise forbidden("NOT_OWNER")
    if appointment.get("status") in {"REJECTED", "CANCELLED", "COMPLETED"}:
        raise failed_precondition("INVALID_TRANSITION")
    if not is_admin and appointment.get("status") == "CONFIRMED":
        notice = bounded_setting(_config(db).get("cancellationNoticeHours"), 24, 0, 720)
        if aware_utc(appointment["confirmedStartAt"]) < utc_now() + timedelta(
            hours=notice
        ):
            raise failed_precondition("CANCELLATION_WINDOW_CLOSED")
    with transaction() as session:
        if appointment.get("status") == "CONFIRMED":
            db.appointment_locks.delete_many(
                {"holderId": appointment_id}, **session_args(session)
            )
        db.appointments.update_one(
            {"_id": appointment_id, "status": appointment["status"]},
            {
                "$set": {
                    "status": "CANCELLED",
                    "cancelledAt": utc_now(),
                    "cancelledBy": user_id,
                    "updatedAt": utc_now(),
                },
                "$push": {
                    "history": _history(appointment["status"], "CANCELLED", user_id)
                },
            },
            **session_args(session),
        )
    return {**appointment, "status": "CANCELLED"}


def admin_complete(
    db: Database[dict[str, Any]], user_id: str, appointment_id: str
) -> Appointment:
    appointment = db.appointments.find_one(
        {"_id": appointment_id, "status": "CONFIRMED"}
    )
    if not appointment:
        raise failed_precondition("INVALID_TRANSITION")
    db.appointments.update_one(
        {"_id": appointment_id, "status": "CONFIRMED"},
        {
            "$set": {
                "status": "COMPLETED",
                "completedAt": utc_now(),
                "updatedAt": utc_now(),
            },
            "$push": {"history": _history("CONFIRMED", "COMPLETED", user_id)},
        },
    )
    return {**appointment, "status": "COMPLETED"}


def admin_reschedule(
    db: Database[dict[str, Any]],
    user_id: str,
    appointment_id: str,
    new_start_at: datetime,
) -> Appointment:
    appointment = db.appointments.find_one(
        {"_id": appointment_id, "status": "CONFIRMED"}
    )
    if not appointment:
        raise failed_precondition("INVALID_TRANSITION")
    new_start = aware_utc(new_start_at)
    duration = int(appointment["durationMinutes"])
    buffer_minutes = int(appointment.get("bufferMinutes") or 0)
    new_end = new_start + timedelta(minutes=duration)
    new_lock_end = new_end + timedelta(minutes=buffer_minutes)
    ensure_within_opening_hours(new_start, new_lock_end, _config(db))
    old_ids = set(
        lock_bucket_ids(
            appointment["confirmedStartAt"],
            appointment["confirmedEndAt"] + timedelta(minutes=buffer_minutes),
        )
    )
    new_ids = set(lock_bucket_ids(new_start, new_lock_end))
    conflicts = db.appointment_locks.find_one(
        {"_id": {"$in": list(new_ids)}, "holderId": {"$ne": appointment_id}}
    )
    if conflicts:
        raise failed_precondition("SLOT_UNAVAILABLE")
    with transaction() as session:
        new_only = new_ids - old_ids
        if new_only:
            try:
                db.appointment_locks.insert_many(
                    [
                        {
                            "_id": item,
                            "holderId": appointment_id,
                            "holderType": "appointment",
                            "updatedAt": utc_now(),
                        }
                        for item in new_only
                    ],
                    **session_args(session),
                )
            except (BulkWriteError, DuplicateKeyError) as error:
                raise failed_precondition("SLOT_UNAVAILABLE") from error
        db.appointment_locks.delete_many(
            {"_id": {"$in": list(old_ids - new_ids)}, "holderId": appointment_id},
            **session_args(session),
        )
        db.appointments.update_one(
            {"_id": appointment_id, "status": "CONFIRMED"},
            {
                "$set": {
                    "confirmedStartAt": new_start,
                    "confirmedEndAt": new_end,
                    "rescheduledAt": utc_now(),
                    "rescheduledBy": user_id,
                    "updatedAt": utc_now(),
                    "reminderSent": False,
                },
                "$push": {
                    "history": {
                        "action": "RESCHEDULED",
                        "fromStartAt": appointment["confirmedStartAt"],
                        "toStartAt": new_start,
                        "at": utc_now(),
                        "actorId": user_id,
                    }
                },
            },
            **session_args(session),
        )
    return {**appointment, "confirmedStartAt": new_start, "confirmedEndAt": new_end}


def admin_create_appointment(
    db: Database[dict[str, Any]],
    user_id: str,
    client_id: str,
    service_id: str,
    start_at: datetime,
) -> tuple[str, Appointment]:
    client = db.users.find_one({"_id": client_id, "deletedAt": None})
    service = db.services.find_one({"_id": service_id})
    if not client or not service:
        raise not_found("CLIENT_OR_SERVICE_NOT_FOUND")
    start = aware_utc(start_at)
    duration = int(service["durationMinutes"])
    buffer_minutes = int(service.get("bufferMinutes") or 0)
    end = start + timedelta(minutes=duration)
    lock_end = end + timedelta(minutes=buffer_minutes)
    ensure_within_opening_hours(start, lock_end, _config(db))
    appointment_id = str(uuid4())
    now = utc_now()
    appointment: Appointment = {
        "_id": appointment_id,
        "clientId": client_id,
        "clientName": f"{client.get('firstName', '')} {client.get('lastName', '')}".strip()
        or "Cliente",
        "clientPhone": client.get("phone"),
        "serviceId": service_id,
        "serviceName": service["name"],
        "durationMinutes": duration,
        "bufferMinutes": buffer_minutes,
        "status": "CONFIRMED",
        "requestedStartAt": start,
        "requestedEndAt": end,
        "confirmedStartAt": start,
        "confirmedEndAt": end,
        "createdAt": now,
        "updatedAt": now,
        "confirmedAt": now,
        "reminderSent": False,
        "history": [_history(None, "CONFIRMED", user_id)],
    }
    with transaction() as session:
        _acquire_locks(db, start, lock_end, appointment_id, session)
        db.appointments.insert_one(appointment, **session_args(session))
    return appointment_id, appointment


def admin_create_block(
    db: Database[dict[str, Any]],
    user_id: str,
    start_at: datetime,
    end_at: datetime,
    reason: str,
) -> str:
    start = aware_utc(start_at)
    end = aware_utc(end_at)
    if end <= start or end - start > timedelta(days=14):
        raise bad_request("INVALID_BLOCK_INTERVAL")
    block_id = str(uuid4())
    db.blocks.insert_one(
        {
            "_id": block_id,
            "startAt": start,
            "endAt": end,
            "reason": reason.strip(),
            "active": True,
            "createdBy": user_id,
            "createdAt": utc_now(),
        }
    )
    return block_id
