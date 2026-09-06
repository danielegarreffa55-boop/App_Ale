from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any, Literal

from google.cloud import firestore
from google.cloud.firestore import Client

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


def _config(db: Client) -> dict[str, Any]:
    snapshot = db.collection("studio").document("config").get()
    return snapshot.to_dict() or {
        "timezone": "Europe/Rome",
        "openingHours": DEFAULT_OPENING_HOURS,
    }


def _history(previous: str | None, current: str, actor_uid: str) -> dict[str, Any]:
    return {"from": previous, "to": current, "at": utc_now(), "actorUid": actor_uid}


def rate_limit(
    db: Client,
    uid: str,
    action: str,
    maximum: int,
    window_seconds: int = 60,
) -> None:
    reference = db.collection("rateLimits").document(f"{uid}_{action}")

    @firestore.transactional
    def update(transaction: firestore.Transaction) -> None:
        snapshot = reference.get(transaction=transaction)
        now = utc_now()
        data = snapshot.to_dict() or {}
        window_start = data.get("windowStart")
        expired = (
            not isinstance(window_start, datetime)
            or (now - aware_utc(window_start)).total_seconds() > window_seconds
        )
        count = 0 if expired else int(data.get("count") or 0)
        if count >= maximum:
            raise ApiError(429, "resource-exhausted", "RATE_LIMITED")
        transaction.set(
            reference,
            {
                "windowStart": now if expired else window_start,
                "count": count + 1,
                "expiresAt": now + timedelta(seconds=window_seconds * 2),
            },
        )

    update(db.transaction())


def _lock_references(db: Client, start_at: datetime, end_at: datetime) -> list[Any]:
    return [
        db.collection("appointmentLocks").document(bucket_id)
        for bucket_id in lock_bucket_ids(start_at, end_at)
    ]


def _read_locks(transaction: firestore.Transaction, references: list[Any]) -> list[Any]:
    return [reference.get(transaction=transaction) for reference in references]


def _acquire_locks(
    transaction: firestore.Transaction,
    references: list[Any],
    snapshots: list[Any],
    holder_id: str,
) -> None:
    for snapshot in snapshots:
        data = snapshot.to_dict() or {}
        replaceable_block = data.get("holderType") == "block"
        if (
            snapshot.exists
            and data.get("holderId") != holder_id
            and not replaceable_block
        ):
            raise failed_precondition("SLOT_UNAVAILABLE")
    now = utc_now()
    for reference in references:
        bucket_start = datetime.fromtimestamp(
            int(reference.id) * 5 * 60,
            tz=timezone.utc,
        )
        transaction.set(
            reference,
            {
                "holderId": holder_id,
                "holderType": "appointment",
                "bucketStartAt": bucket_start,
                "updatedAt": now,
            },
        )


def _release_locks(
    transaction: firestore.Transaction,
    references: list[Any],
    snapshots: list[Any],
    holder_id: str,
) -> None:
    for reference, snapshot in zip(references, snapshots, strict=True):
        data = snapshot.to_dict() or {}
        if snapshot.exists and data.get("holderId") == holder_id:
            transaction.delete(reference)


def availability(
    db: Client,
    uid: str,
    service_id: str,
    day: date,
) -> list[dict[str, str]]:
    rate_limit(db, uid, "availability", 60)
    service_snapshot = db.collection("services").document(service_id).get()
    service = service_snapshot.to_dict() or {}
    if not service_snapshot.exists or service.get("active") is not True:
        raise not_found("SERVICE_NOT_FOUND")
    return slots_for_day(day, service, _config(db))


def create_request(
    db: Client,
    user: dict[str, Any],
    service_id: str,
    requested_start_at: datetime,
) -> str:
    uid = str(user["uid"])
    rate_limit(db, uid, "createAppointment", 10, 3600)
    if user.get("email_verified") is not True:
        raise failed_precondition("EMAIL_NOT_VERIFIED")
    start_at = aware_utc(requested_start_at)
    service_ref = db.collection("services").document(service_id)
    profile_ref = db.collection("users").document(uid)
    service_snapshot = service_ref.get()
    profile_snapshot = profile_ref.get()
    service = service_snapshot.to_dict() or {}
    profile = profile_snapshot.to_dict() or {}
    config = _config(db)
    if not service_snapshot.exists or service.get("active") is not True:
        raise not_found("SERVICE_NOT_FOUND")
    if not profile_snapshot.exists:
        raise failed_precondition("PROFILE_REQUIRED")
    lead = bounded_setting(config.get("minimumLeadMinutes"), 120, 0, 43_200)
    if start_at < utc_now() + timedelta(minutes=lead):
        raise bad_request("DATE_TOO_SOON")
    horizon = bounded_setting(config.get("bookingHorizonDays"), 90, 1, 730)
    zone_name = config.get("timezone") or "Europe/Rome"
    from zoneinfo import ZoneInfo

    local_start = start_at.astimezone(ZoneInfo(zone_name))
    if local_start.date() > utc_now().astimezone(
        ZoneInfo(zone_name)
    ).date() + timedelta(days=horizon):
        raise bad_request("DATE_OUT_OF_RANGE")
    duration = int(service["durationMinutes"])
    buffer_minutes = int(service.get("bufferMinutes") or 0)
    end_at = start_at + timedelta(minutes=duration)
    ensure_within_opening_hours(
        start_at,
        end_at + timedelta(minutes=buffer_minutes),
        config,
    )
    reference = db.collection("appointments").document()
    now = utc_now()
    client_name = (
        f"{profile.get('firstName', '')} {profile.get('lastName', '')}".strip()
    )
    reference.create(
        {
            "clientId": uid,
            "clientName": client_name or "Cliente",
            "clientPhone": profile.get("phone"),
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
            "history": [_history(None, "PENDING_ADMIN", uid)],
        }
    )
    return reference.id


def _confirm(
    db: Client,
    appointment_id: str,
    candidate: Literal["requested", "proposed"],
    actor_uid: str,
    is_admin: bool,
) -> Appointment:
    reference = db.collection("appointments").document(appointment_id)

    @firestore.transactional
    def confirm(transaction: firestore.Transaction) -> Appointment:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if is_admin:
            valid = (
                candidate == "requested"
                and appointment.get("status") == "PENDING_ADMIN"
            )
        else:
            valid = (
                appointment.get("clientId") == actor_uid
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
        config_snapshot = (
            db.collection("studio").document("config").get(transaction=transaction)
        )
        config = config_snapshot.to_dict() or {
            "timezone": "Europe/Rome",
            "openingHours": DEFAULT_OPENING_HOURS,
        }
        ensure_within_opening_hours(start_at, lock_end, config)
        lock_refs = _lock_references(db, start_at, lock_end)
        lock_snapshots = _read_locks(transaction, lock_refs)
        _acquire_locks(transaction, lock_refs, lock_snapshots, appointment_id)
        now = utc_now()
        transaction.update(
            reference,
            {
                "status": "CONFIRMED",
                "confirmedStartAt": start_at,
                "confirmedEndAt": end_at,
                "confirmedAt": now,
                "updatedAt": now,
                "reminderSent": False,
                "history": firestore.ArrayUnion(
                    [_history(appointment["status"], "CONFIRMED", actor_uid)]
                ),
            },
        )
        return {
            **appointment,
            "status": "CONFIRMED",
            "confirmedStartAt": start_at,
            "confirmedEndAt": end_at,
        }

    return confirm(db.transaction())


def admin_accept(db: Client, uid: str, appointment_id: str) -> Appointment:
    return _confirm(db, appointment_id, "requested", uid, True)


def admin_reject(
    db: Client,
    uid: str,
    appointment_id: str,
    reason: str | None,
) -> None:
    reference = db.collection("appointments").document(appointment_id)

    @firestore.transactional
    def reject(transaction: firestore.Transaction) -> None:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
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
            "history": firestore.ArrayUnion(
                [_history(appointment["status"], "REJECTED", uid)]
            ),
        }
        changes["adminReason"] = (
            reason.strip() if reason and reason.strip() else firestore.DELETE_FIELD
        )
        transaction.update(reference, changes)

    reject(db.transaction())


def admin_counter_propose(
    db: Client,
    uid: str,
    appointment_id: str,
    proposed_start_at: datetime,
) -> None:
    reference = db.collection("appointments").document(appointment_id)
    proposed_start = aware_utc(proposed_start_at)

    @firestore.transactional
    def propose(transaction: firestore.Transaction) -> None:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if appointment.get("status") not in {
            "PENDING_ADMIN",
            "COUNTER_PROPOSED",
            "COUNTER_REJECTED",
        }:
            raise failed_precondition("INVALID_TRANSITION")
        duration = int(appointment["durationMinutes"])
        buffer_minutes = int(appointment.get("bufferMinutes") or 0)
        end_at = proposed_start + timedelta(minutes=duration)
        lock_end = end_at + timedelta(minutes=buffer_minutes)
        config_snapshot = (
            db.collection("studio").document("config").get(transaction=transaction)
        )
        config = config_snapshot.to_dict() or {
            "timezone": "Europe/Rome",
            "openingHours": DEFAULT_OPENING_HOURS,
        }
        ensure_within_opening_hours(proposed_start, lock_end, config)
        locks = _read_locks(transaction, _lock_references(db, proposed_start, lock_end))
        if any(
            item.exists and (item.to_dict() or {}).get("holderType") != "block"
            for item in locks
        ):
            raise failed_precondition("SLOT_UNAVAILABLE")
        transaction.update(
            reference,
            {
                "status": "COUNTER_PROPOSED",
                "originalStartAt": appointment.get("originalStartAt")
                or appointment["requestedStartAt"],
                "proposedStartAt": proposed_start,
                "proposedEndAt": end_at,
                "counterProposedAt": utc_now(),
                "counterProposedBy": uid,
                "updatedAt": utc_now(),
                "history": firestore.ArrayUnion(
                    [_history(appointment["status"], "COUNTER_PROPOSED", uid)]
                ),
            },
        )

    propose(db.transaction())


def client_counter_response(
    db: Client,
    uid: str,
    appointment_id: str,
    accept: bool,
) -> tuple[str, Appointment | None]:
    rate_limit(db, uid, "counterResponse", 10, 3600)
    if accept:
        appointment = _confirm(db, appointment_id, "proposed", uid, False)
        return "CONFIRMED", appointment
    reference = db.collection("appointments").document(appointment_id)

    @firestore.transactional
    def reject(transaction: firestore.Transaction) -> None:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if (
            appointment.get("clientId") != uid
            or appointment.get("status") != "COUNTER_PROPOSED"
        ):
            raise forbidden("INVALID_TRANSITION")
        transaction.update(
            reference,
            {
                "status": "COUNTER_REJECTED",
                "counterRejectedAt": utc_now(),
                "updatedAt": utc_now(),
                "history": firestore.ArrayUnion(
                    [_history("COUNTER_PROPOSED", "COUNTER_REJECTED", uid)]
                ),
            },
        )

    reject(db.transaction())
    return "COUNTER_REJECTED", None


def cancel(
    db: Client,
    user: dict[str, Any],
    appointment_id: str,
) -> Appointment:
    uid = str(user["uid"])
    is_admin = user.get("admin") is True
    reference = db.collection("appointments").document(appointment_id)

    @firestore.transactional
    def cancel_in_transaction(transaction: firestore.Transaction) -> Appointment:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if not is_admin and appointment.get("clientId") != uid:
            raise forbidden("NOT_OWNER")
        if appointment.get("status") in {"REJECTED", "CANCELLED", "COMPLETED"}:
            raise failed_precondition("INVALID_TRANSITION")
        config: dict[str, Any] = {}
        if not is_admin and appointment.get("status") == "CONFIRMED":
            config_snapshot = (
                db.collection("studio").document("config").get(transaction=transaction)
            )
            config = config_snapshot.to_dict() or {}
            notice = bounded_setting(config.get("cancellationNoticeHours"), 24, 0, 720)
            confirmed = aware_utc(appointment["confirmedStartAt"])
            if confirmed < utc_now() + timedelta(hours=notice):
                raise failed_precondition("CANCELLATION_WINDOW_CLOSED")
        if appointment.get("status") == "CONFIRMED" and isinstance(
            appointment.get("confirmedStartAt"), datetime
        ):
            start_at = aware_utc(appointment["confirmedStartAt"])
            lock_end = start_at + timedelta(
                minutes=int(appointment["durationMinutes"])
                + int(appointment.get("bufferMinutes") or 0)
            )
            lock_refs = _lock_references(db, start_at, lock_end)
            lock_snapshots = _read_locks(transaction, lock_refs)
            _release_locks(transaction, lock_refs, lock_snapshots, appointment_id)
        transaction.update(
            reference,
            {
                "status": "CANCELLED",
                "cancelledAt": utc_now(),
                "cancelledBy": uid,
                "updatedAt": utc_now(),
                "history": firestore.ArrayUnion(
                    [_history(appointment["status"], "CANCELLED", uid)]
                ),
            },
        )
        return {**appointment, "status": "CANCELLED"}

    return cancel_in_transaction(db.transaction())


def admin_complete(db: Client, uid: str, appointment_id: str) -> None:
    reference = db.collection("appointments").document(appointment_id)

    @firestore.transactional
    def complete(transaction: firestore.Transaction) -> None:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if appointment.get("status") != "CONFIRMED":
            raise failed_precondition("INVALID_TRANSITION")
        transaction.update(
            reference,
            {
                "status": "COMPLETED",
                "completedAt": utc_now(),
                "updatedAt": utc_now(),
                "history": firestore.ArrayUnion(
                    [_history("CONFIRMED", "COMPLETED", uid)]
                ),
            },
        )

    complete(db.transaction())


def admin_reschedule(
    db: Client,
    uid: str,
    appointment_id: str,
    new_start_at: datetime,
) -> Appointment:
    reference = db.collection("appointments").document(appointment_id)
    new_start = aware_utc(new_start_at)

    @firestore.transactional
    def reschedule(transaction: firestore.Transaction) -> Appointment:
        snapshot = reference.get(transaction=transaction)
        if not snapshot.exists:
            raise not_found("APPOINTMENT_NOT_FOUND")
        appointment = snapshot.to_dict() or {}
        if appointment.get("status") != "CONFIRMED" or not isinstance(
            appointment.get("confirmedStartAt"), datetime
        ):
            raise failed_precondition("INVALID_TRANSITION")
        duration = int(appointment["durationMinutes"])
        buffer_minutes = int(appointment.get("bufferMinutes") or 0)
        new_end = new_start + timedelta(minutes=duration)
        new_lock_end = new_end + timedelta(minutes=buffer_minutes)
        old_start = aware_utc(appointment["confirmedStartAt"])
        old_lock_end = old_start + timedelta(minutes=duration + buffer_minutes)
        config_snapshot = (
            db.collection("studio").document("config").get(transaction=transaction)
        )
        config = config_snapshot.to_dict() or {
            "timezone": "Europe/Rome",
            "openingHours": DEFAULT_OPENING_HOURS,
        }
        ensure_within_opening_hours(new_start, new_lock_end, config)
        old_refs = _lock_references(db, old_start, old_lock_end)
        new_refs = _lock_references(db, new_start, new_lock_end)
        all_refs = {reference.path: reference for reference in old_refs + new_refs}
        snapshots = _read_locks(transaction, list(all_refs.values()))
        by_path = {item.reference.path: item for item in snapshots}
        new_paths = {item.path for item in new_refs}
        for lock_ref in new_refs:
            lock = by_path[lock_ref.path]
            lock_data = lock.to_dict() or {}
            if (
                lock.exists
                and lock_data.get("holderId") != appointment_id
                and lock_data.get("holderType") != "block"
            ):
                raise failed_precondition("SLOT_UNAVAILABLE")
        for lock_ref in old_refs:
            lock = by_path[lock_ref.path]
            if (
                lock_ref.path not in new_paths
                and lock.exists
                and (lock.to_dict() or {}).get("holderId") == appointment_id
            ):
                transaction.delete(lock_ref)
        _acquire_locks(
            transaction,
            new_refs,
            [by_path[item.path] for item in new_refs],
            appointment_id,
        )
        transaction.update(
            reference,
            {
                "confirmedStartAt": new_start,
                "confirmedEndAt": new_end,
                "rescheduledAt": utc_now(),
                "rescheduledBy": uid,
                "updatedAt": utc_now(),
                "history": firestore.ArrayUnion(
                    [
                        {
                            "action": "RESCHEDULED",
                            "fromStartAt": appointment["confirmedStartAt"],
                            "toStartAt": new_start,
                            "at": utc_now(),
                            "actorUid": uid,
                        }
                    ]
                ),
            },
        )
        return {**appointment, "confirmedStartAt": new_start, "confirmedEndAt": new_end}

    return reschedule(db.transaction())


def admin_create_appointment(
    db: Client,
    uid: str,
    client_id: str,
    service_id: str,
    start_at: datetime,
) -> tuple[str, Appointment]:
    start = aware_utc(start_at)
    appointment_ref = db.collection("appointments").document()

    @firestore.transactional
    def create(transaction: firestore.Transaction) -> Appointment:
        service_snapshot = (
            db.collection("services").document(service_id).get(transaction=transaction)
        )
        client_snapshot = (
            db.collection("users").document(client_id).get(transaction=transaction)
        )
        config_snapshot = (
            db.collection("studio").document("config").get(transaction=transaction)
        )
        if not service_snapshot.exists or not client_snapshot.exists:
            raise not_found("CLIENT_OR_SERVICE_NOT_FOUND")
        service = service_snapshot.to_dict() or {}
        client = client_snapshot.to_dict() or {}
        config = config_snapshot.to_dict() or {
            "timezone": "Europe/Rome",
            "openingHours": DEFAULT_OPENING_HOURS,
        }
        duration = int(service["durationMinutes"])
        buffer_minutes = int(service.get("bufferMinutes") or 0)
        end = start + timedelta(minutes=duration)
        lock_end = end + timedelta(minutes=buffer_minutes)
        ensure_within_opening_hours(start, lock_end, config)
        lock_refs = _lock_references(db, start, lock_end)
        lock_snapshots = _read_locks(transaction, lock_refs)
        _acquire_locks(
            transaction,
            lock_refs,
            lock_snapshots,
            appointment_ref.id,
        )
        now = utc_now()
        client_name = (
            f"{client.get('firstName', '')} {client.get('lastName', '')}".strip()
        )
        appointment: Appointment = {
            "clientId": client_id,
            "clientName": client_name or "Cliente",
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
            "history": [_history(None, "CONFIRMED", uid)],
        }
        transaction.create(appointment_ref, appointment)
        return appointment

    return appointment_ref.id, create(db.transaction())


def admin_create_block(
    db: Client,
    uid: str,
    start_at: datetime,
    end_at: datetime,
    reason: str,
) -> str:
    start = aware_utc(start_at)
    end = aware_utc(end_at)
    if end <= start or end - start > timedelta(days=14):
        raise bad_request("INVALID_BLOCK_INTERVAL")
    reference = db.collection("blocks").document()
    reference.create(
        {
            "startAt": start,
            "endAt": end,
            "reason": reason.strip(),
            "active": True,
            "createdBy": uid,
            "createdAt": utc_now(),
        }
    )
    return reference.id
