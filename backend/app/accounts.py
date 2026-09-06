from __future__ import annotations

from datetime import timedelta
from typing import Any
from uuid import uuid4

from pymongo.database import Database
from pymongo.errors import DuplicateKeyError

from . import auth
from .errors import ApiError, failed_precondition, not_found
from .scheduling import utc_now


def public_user(user: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(user["_id"]),
        "email": user.get("email", ""),
        "firstName": user.get("firstName", ""),
        "lastName": user.get("lastName", ""),
        "displayName": (
            f"{user.get('firstName', '')} {user.get('lastName', '')}".strip()
        ),
        "phone": user.get("phone", ""),
        "role": user.get("role", "client"),
        "emailVerified": user.get("emailVerified") is True,
        "createdAt": user.get("createdAt"),
    }


def register(
    db: Database[dict[str, Any]], data: dict[str, Any]
) -> tuple[dict[str, Any], str]:
    now = utc_now()
    user = {
        "_id": str(uuid4()),
        "email": str(data["email"]).strip().lower(),
        "emailLower": str(data["email"]).strip().lower(),
        "firstName": data["firstName"].strip(),
        "lastName": data["lastName"].strip(),
        "phone": data["phone"].strip(),
        "passwordHash": auth.hash_password(data["password"]),
        "role": "client",
        "emailVerified": False,
        "privacyAcceptedAt": now,
        "sessionVersion": 0,
        "createdAt": now,
        "updatedAt": now,
        "deletedAt": None,
    }
    try:
        db.users.insert_one(user)
    except DuplicateKeyError as error:
        raise ApiError(409, "already-exists", "EMAIL_ALREADY_IN_USE") from error
    token = auth.create_opaque_token(
        db, user["_id"], "verify-email", timedelta(hours=24)
    )
    return user, token


def authenticate(
    db: Database[dict[str, Any]], email: str, password: str
) -> dict[str, Any]:
    user = db.users.find_one({"emailLower": email.strip().lower(), "deletedAt": None})
    password_hash = user.get("passwordHash", "") if user else auth.dummy_password_hash()
    if not auth.verify_password(password_hash, password) or not user:
        raise ApiError(401, "unauthenticated", "INVALID_CREDENTIALS")
    if auth.password_needs_rehash(user["passwordHash"]):
        db.users.update_one(
            {"_id": user["_id"]},
            {
                "$set": {
                    "passwordHash": auth.hash_password(password),
                    "updatedAt": utc_now(),
                }
            },
        )
    return user


def update_profile(
    db: Database[dict[str, Any]], user_id: str, data: dict[str, Any]
) -> dict[str, Any]:
    db.users.update_one(
        {"_id": user_id, "deletedAt": None},
        {
            "$set": {
                "firstName": data["firstName"].strip(),
                "lastName": data["lastName"].strip(),
                "phone": data["phone"].strip(),
                "updatedAt": utc_now(),
            }
        },
    )
    user = db.users.find_one({"_id": user_id, "deletedAt": None})
    if not user:
        raise not_found("USER_NOT_FOUND")
    return user


def verify_email(db: Database[dict[str, Any]], token: str) -> dict[str, Any]:
    user = auth.consume_opaque_token(db, token, "verify-email")
    db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "emailVerified": True,
                "emailVerifiedAt": utc_now(),
                "updatedAt": utc_now(),
            }
        },
    )
    return db.users.find_one({"_id": user["_id"]}) or user


def set_role(
    db: Database[dict[str, Any]], owner_id: str, target_id: str, role: str
) -> None:
    if owner_id == target_id and role != "owner":
        raise failed_precondition("CANNOT_CHANGE_OWN_OWNER_ROLE")
    result = db.users.update_one(
        {"_id": target_id, "deletedAt": None},
        {
            "$set": {
                "role": role,
                "roleUpdatedAt": utc_now(),
                "roleUpdatedBy": owner_id,
                "updatedAt": utc_now(),
            },
            "$inc": {"sessionVersion": 1},
        },
    )
    if result.matched_count != 1:
        raise not_found("USER_NOT_FOUND")
    db.refresh_tokens.update_many(
        {"userId": target_id, "revokedAt": None},
        {"$set": {"revokedAt": utc_now(), "revokeReason": "ROLE_CHANGED"}},
    )


def delete_account(db: Database[dict[str, Any]], user: dict[str, Any]) -> None:
    user_id = str(user["_id"])
    if user.get("role") == "owner":
        raise failed_precondition("OWNER_ACCOUNT_CANNOT_BE_DELETED")
    now = utc_now()
    db.appointments.update_many(
        {"clientId": user_id},
        {
            "$set": {
                "clientName": "Cliente eliminato",
                "clientPhone": None,
                "updatedAt": now,
            }
        },
    )
    db.users.update_one(
        {"_id": user_id},
        {
            "$set": {
                "email": "",
                "emailLower": f"deleted-{user_id}@invalid.local",
                "firstName": "",
                "lastName": "",
                "phone": "",
                "passwordHash": "!deleted",
                "role": "client",
                "deletedAt": now,
                "updatedAt": now,
            },
            "$inc": {"sessionVersion": 1},
        },
    )
    db.refresh_tokens.delete_many({"userId": user_id})
    db.auth_tokens.delete_many({"userId": user_id})
    db.notification_logs.delete_many({"userId": user_id})
