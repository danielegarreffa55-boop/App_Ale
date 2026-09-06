from __future__ import annotations

from typing import Any, Annotated

from fastapi import Depends, Header
from firebase_admin import auth

from .errors import ApiError, forbidden
from .firebase import ensure_firebase_app

Claims = dict[str, Any]


def current_user(
    authorization: Annotated[str | None, Header()] = None,
) -> Claims:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "unauthenticated", "AUTH_REQUIRED")
    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise ApiError(401, "unauthenticated", "AUTH_REQUIRED")
    ensure_firebase_app()
    try:
        return auth.verify_id_token(token, check_revoked=True)
    except Exception as error:
        raise ApiError(401, "unauthenticated", "INVALID_AUTH_TOKEN") from error


def admin_user(user: Annotated[Claims, Depends(current_user)]) -> Claims:
    if user.get("admin") is not True:
        raise forbidden("ADMIN_REQUIRED")
    return user


def owner_user(user: Annotated[Claims, Depends(current_user)]) -> Claims:
    if user.get("owner") is not True:
        raise forbidden("OWNER_REQUIRED")
    return user
