from __future__ import annotations

from datetime import timedelta
from hashlib import sha256
import secrets
from threading import BoundedSemaphore
from typing import Annotated, Any
from uuid import uuid4

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from fastapi import Depends, Header
import jwt
from pymongo.database import Database

from .config import settings
from .database import database
from .errors import ApiError, forbidden
from .scheduling import utc_now

User = dict[str, Any]
_passwords = PasswordHasher(time_cost=3, memory_cost=65_536, parallelism=2)
_password_slots = BoundedSemaphore(4)
_dummy_password_hash = _passwords.hash("not-a-real-user-password")


def hash_password(password: str) -> str:
    with _password_slots:
        return _passwords.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    try:
        with _password_slots:
            return _passwords.verify(password_hash, password)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False


def password_needs_rehash(password_hash: str) -> bool:
    try:
        return _passwords.check_needs_rehash(password_hash)
    except InvalidHashError:
        return True


def dummy_password_hash() -> str:
    return _dummy_password_hash


def _encode(user: User, token_type: str, expires_delta: timedelta, jti: str) -> str:
    now = utc_now()
    payload = {
        "sub": str(user["_id"]),
        "type": token_type,
        "jti": jti,
        "sv": int(user.get("sessionVersion") or 0),
        "role": user.get("role") or "client",
        "iat": now,
        "nbf": now,
        "exp": now + expires_delta,
        "iss": settings().jwt_issuer,
    }
    return jwt.encode(payload, settings().jwt_secret, algorithm="HS256")


def decode_token(token: str, expected_type: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings().jwt_secret,
            algorithms=["HS256"],
            issuer=settings().jwt_issuer,
            options={"require": ["sub", "type", "jti", "sv", "exp", "iat"]},
        )
    except jwt.PyJWTError as error:
        raise ApiError(401, "unauthenticated", "INVALID_AUTH_TOKEN") from error
    if payload.get("type") != expected_type:
        raise ApiError(401, "unauthenticated", "INVALID_AUTH_TOKEN")
    return payload


def create_token_pair(
    db: Database[dict[str, Any]], user: User, family_id: str | None = None
) -> dict[str, Any]:
    access_jti = str(uuid4())
    refresh_jti = str(uuid4())
    refresh_family_id = family_id or str(uuid4())
    access = _encode(
        user,
        "access",
        timedelta(minutes=settings().access_token_minutes),
        access_jti,
    )
    refresh = _encode(
        user,
        "refresh",
        timedelta(days=settings().refresh_token_days),
        refresh_jti,
    )
    db.refresh_tokens.insert_one(
        {
            "_id": refresh_jti,
            "userId": str(user["_id"]),
            "tokenHash": sha256(refresh.encode()).hexdigest(),
            "familyId": refresh_family_id,
            "createdAt": utc_now(),
            "expiresAt": utc_now() + timedelta(days=settings().refresh_token_days),
            "revokedAt": None,
        }
    )
    return {
        "accessToken": access,
        "refreshToken": refresh,
        "expiresIn": settings().access_token_minutes * 60,
    }


def rotate_refresh_token(
    db: Database[dict[str, Any]], token: str
) -> tuple[User, dict[str, Any]]:
    payload = decode_token(token, "refresh")
    token_hash = sha256(token.encode()).hexdigest()
    record = db.refresh_tokens.find_one_and_update(
        {
            "_id": payload["jti"],
            "tokenHash": token_hash,
            "revokedAt": None,
            "expiresAt": {"$gt": utc_now()},
        },
        {"$set": {"revokedAt": utc_now(), "revokeReason": "ROTATED"}},
    )
    if not record:
        replayed = db.refresh_tokens.find_one(
            {"_id": payload["jti"], "tokenHash": token_hash}
        )
        if replayed and replayed.get("userId"):
            revoke_all_sessions(db, str(replayed["userId"]))
        raise ApiError(401, "unauthenticated", "INVALID_REFRESH_TOKEN")
    user = db.users.find_one({"_id": payload["sub"], "deletedAt": None})
    if not user or int(user.get("sessionVersion") or 0) != int(payload["sv"]):
        raise ApiError(401, "unauthenticated", "SESSION_REVOKED")
    return user, create_token_pair(db, user, str(record.get("familyId") or ""))


def revoke_refresh_token(db: Database[dict[str, Any]], token: str) -> None:
    try:
        payload = decode_token(token, "refresh")
    except ApiError:
        return
    db.refresh_tokens.update_one(
        {"_id": payload["jti"]},
        {"$set": {"revokedAt": utc_now(), "revokeReason": "LOGOUT"}},
    )


def revoke_all_sessions(db: Database[dict[str, Any]], user_id: str) -> None:
    db.users.update_one({"_id": user_id}, {"$inc": {"sessionVersion": 1}})
    db.refresh_tokens.update_many(
        {"userId": user_id, "revokedAt": None},
        {"$set": {"revokedAt": utc_now(), "revokeReason": "REVOKE_ALL"}},
    )


def create_opaque_token(
    db: Database[dict[str, Any]],
    user_id: str,
    purpose: str,
    lifetime: timedelta,
) -> str:
    raw = secrets.token_urlsafe(40)
    digest = sha256(raw.encode()).hexdigest()
    db.auth_tokens.delete_many({"userId": user_id, "purpose": purpose})
    db.auth_tokens.insert_one(
        {
            "_id": digest,
            "userId": user_id,
            "purpose": purpose,
            "createdAt": utc_now(),
            "expiresAt": utc_now() + lifetime,
        }
    )
    return raw


def consume_opaque_token(
    db: Database[dict[str, Any]], token: str, purpose: str
) -> User:
    digest = sha256(token.encode()).hexdigest()
    record = db.auth_tokens.find_one_and_delete(
        {"_id": digest, "purpose": purpose, "expiresAt": {"$gt": utc_now()}}
    )
    if not record:
        raise ApiError(400, "invalid-argument", "INVALID_OR_EXPIRED_TOKEN")
    user = db.users.find_one({"_id": record["userId"], "deletedAt": None})
    if not user:
        raise ApiError(400, "invalid-argument", "INVALID_OR_EXPIRED_TOKEN")
    return user


def current_user(authorization: Annotated[str | None, Header()] = None) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "unauthenticated", "AUTH_REQUIRED")
    payload = decode_token(authorization.removeprefix("Bearer ").strip(), "access")
    user = database().users.find_one({"_id": payload["sub"], "deletedAt": None})
    if not user or int(user.get("sessionVersion") or 0) != int(payload["sv"]):
        raise ApiError(401, "unauthenticated", "SESSION_REVOKED")
    return user


def admin_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.get("role") not in {"manager", "owner"}:
        raise forbidden("ADMIN_REQUIRED")
    return user


def owner_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.get("role") != "owner":
        raise forbidden("OWNER_REQUIRED")
    return user
