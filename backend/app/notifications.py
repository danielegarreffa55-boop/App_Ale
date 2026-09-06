from __future__ import annotations

from datetime import datetime, timedelta
import logging
from typing import Any
from uuid import uuid4
from zoneinfo import ZoneInfo

import httpx
from pymongo import ReturnDocument
from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from .config import settings
from .scheduling import local_day_bounds, utc_now

logger = logging.getLogger(__name__)


def send_to_user(
    db: Database[dict[str, Any]],
    user_id: str,
    log_id: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> bool:
    now = utc_now()
    provider_idempotency_key = str(uuid4())
    try:
        db.notification_logs.insert_one(
            {
                "_id": log_id,
                "userId": user_id,
                "status": "CLAIMED",
                "type": (data or {}).get("type", "generic"),
                "title": title,
                "body": body,
                "data": data or {},
                "attempts": 1,
                "claimedAt": now,
                "providerIdempotencyKey": provider_idempotency_key,
                "createdAt": now,
            }
        )
    except DuplicateKeyError:
        reclaimed = db.notification_logs.find_one_and_update(
            {
                "_id": log_id,
                "$or": [
                    {"status": {"$in": ["FAILED", "SKIPPED"]}},
                    {
                        "status": "CLAIMED",
                        "claimedAt": {"$lt": now - timedelta(minutes=5)},
                    },
                ],
            },
            {
                "$set": {"status": "CLAIMED", "claimedAt": now},
                "$inc": {"attempts": 1},
            },
            return_document=ReturnDocument.AFTER,
        )
        if not reclaimed:
            return False
        provider_idempotency_key = str(
            reclaimed.get("providerIdempotencyKey") or provider_idempotency_key
        )
    config = settings()
    if not config.onesignal_app_id or not config.onesignal_api_key:
        db.notification_logs.update_one(
            {"_id": log_id},
            {"$set": {"status": "SKIPPED", "reason": "ONESIGNAL_NOT_CONFIGURED"}},
        )
        return False
    payload: dict[str, Any] = {
        "app_id": config.onesignal_app_id,
        "target_channel": "push",
        "include_aliases": {"external_id": [user_id]},
        "headings": {"it": title, "en": title},
        "contents": {"it": body, "en": body},
        "data": data or {},
        "idempotency_key": provider_idempotency_key,
    }
    try:
        response = httpx.post(
            "https://api.onesignal.com/notifications",
            headers={
                "Authorization": f"Key {config.onesignal_api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=15,
        )
        response.raise_for_status()
        response_data = response.json()
        if not response_data.get("id"):
            raise RuntimeError("ONESIGNAL_NO_MATCHING_SUBSCRIPTION")
        db.notification_logs.update_one(
            {"_id": log_id},
            {
                "$set": {
                    "status": "SENT",
                    "provider": "onesignal",
                    "providerMessageId": response_data.get("id"),
                    "sentAt": utc_now(),
                }
            },
        )
        return True
    except Exception as error:
        logger.exception("OneSignal notification failed for %s", user_id)
        db.notification_logs.update_one(
            {"_id": log_id},
            {"$set": {"status": "FAILED", "error": str(error)[:500]}},
        )
        return False


def retry_failed(db: Database[dict[str, Any]], limit: int = 100) -> int:
    cutoff = utc_now() - timedelta(minutes=10)
    retried = 0
    documents = (
        db.notification_logs.find(
            {
                "status": {"$in": ["FAILED", "SKIPPED"]},
                "attempts": {"$lt": 6},
                "claimedAt": {"$lte": cutoff},
            }
        )
        .sort("claimedAt", 1)
        .limit(limit)
    )
    for document in documents:
        data = {
            str(key): str(value)
            for key, value in dict(document.get("data") or {}).items()
        }
        delivered = send_to_user(
            db,
            str(document["userId"]),
            str(document["_id"]),
            str(document.get("title") or "Alessio Garreffa Hair"),
            str(document.get("body") or "Hai un aggiornamento."),
            data,
        )
        if delivered:
            retried += 1
            if data.get("type") == "reminder" and data.get("appointmentId"):
                db.appointments.update_one(
                    {"_id": data["appointmentId"]},
                    {"$set": {"reminderSent": True, "reminderSentAt": utc_now()}},
                )
    return retried


def send_to_admins(
    db: Database[dict[str, Any]],
    log_prefix: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> None:
    for admin in db.users.find(
        {"role": {"$in": ["manager", "owner"]}, "deletedAt": None}, {"_id": 1}
    ):
        send_to_user(
            db,
            str(admin["_id"]),
            f"{log_prefix}_{admin['_id']}",
            title,
            body,
            data,
        )


def send_reminders(db: Database[dict[str, Any]], now: datetime | None = None) -> int:
    config = db.studio.find_one({"_id": "config"}) or {}
    timezone_name = config.get("timezone") or settings().timezone
    local_now = (now or utc_now()).astimezone(ZoneInfo(timezone_name))
    try:
        reminder_hour, reminder_minute = (
            int(part) for part in str(config.get("reminderTime") or "18:00").split(":")
        )
    except (TypeError, ValueError):
        reminder_hour, reminder_minute = 18, 0
    current_minute = local_now.hour * 60 + local_now.minute
    scheduled_minute = reminder_hour * 60 + reminder_minute
    if not scheduled_minute <= current_minute < scheduled_minute + 20:
        return 0
    tomorrow = local_now.date() + timedelta(days=1)
    start_at, end_at = local_day_bounds(tomorrow, timezone_name)
    sent = 0
    for appointment in db.appointments.find(
        {
            "status": "CONFIRMED",
            "confirmedStartAt": {"$gte": start_at, "$lt": end_at},
            "reminderSent": {"$ne": True},
            "clientId": {"$ne": ""},
        }
    ):
        start = appointment["confirmedStartAt"].astimezone(local_now.tzinfo)
        appointment_id = str(appointment["_id"])
        delivered = send_to_user(
            db,
            appointment["clientId"],
            f"reminder_{appointment_id}_{tomorrow.isoformat()}",
            "Promemoria appuntamento",
            f"Domani alle {start:%H:%M} hai un appuntamento presso "
            f"{config.get('studioName') or 'Alessio Garreffa Hair'}.",
            {"type": "reminder", "appointmentId": appointment_id},
        )
        if delivered:
            db.appointments.update_one(
                {"_id": appointment["_id"]},
                {"$set": {"reminderSent": True, "reminderSentAt": utc_now()}},
            )
            sent += 1
    return sent
