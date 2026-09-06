from __future__ import annotations

from contextlib import contextmanager
from functools import lru_cache
from typing import Any, Iterator

from pymongo import ASCENDING, DESCENDING, MongoClient
from pymongo.database import Database

from .config import settings


@lru_cache
def mongo_client() -> MongoClient[dict[str, Any]]:
    return MongoClient(
        settings().mongo_uri,
        tz_aware=True,
        serverSelectionTimeoutMS=8_000,
        appname="alessio-garreffa-hair-api",
    )


@lru_cache
def database() -> Database[dict[str, Any]]:
    return mongo_client()[settings().mongo_database]


def ensure_indexes(db: Database[dict[str, Any]] | None = None) -> None:
    # PyMongo's Database deliberately has no truth value. An explicit None
    # check also keeps injected test databases and production databases aligned.
    target = db if db is not None else database()
    target.users.create_index("emailLower", unique=True)
    target.users.create_index([("role", ASCENDING), ("lastName", ASCENDING)])
    target.refresh_tokens.create_index("expiresAt", expireAfterSeconds=0)
    target.auth_tokens.create_index("expiresAt", expireAfterSeconds=0)
    target.appointments.create_index(
        [("clientId", ASCENDING), ("createdAt", DESCENDING)]
    )
    target.appointments.create_index(
        [("status", ASCENDING), ("confirmedStartAt", ASCENDING)]
    )
    target.appointments.create_index("googleCalendarEventId", sparse=True)
    target.services.create_index([("active", ASCENDING), ("displayOrder", ASCENDING)])
    target.blocks.create_index([("active", ASCENDING), ("startAt", ASCENDING)])
    target.rate_limits.create_index("expiresAt", expireAfterSeconds=0)
    target.notification_logs.create_index(
        "createdAt",
        expireAfterSeconds=180 * 24 * 60 * 60,
        name="notification_logs_ttl",
    )


@contextmanager
def transaction() -> Iterator[Any | None]:
    if not settings().mongo_transactions:
        yield None
        return
    with mongo_client().start_session() as session:
        with session.start_transaction():
            yield session


def session_args(session: Any | None) -> dict[str, Any]:
    return {"session": session} if session is not None else {}


def public_document(document: dict[str, Any] | None) -> dict[str, Any]:
    if not document:
        return {}
    result = dict(document)
    result["id"] = str(result.pop("_id"))
    result.pop("passwordHash", None)
    result.pop("sessionVersion", None)
    result.pop("emailLower", None)
    return result
