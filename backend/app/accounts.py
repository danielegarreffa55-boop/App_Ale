from __future__ import annotations

from hashlib import sha256
from typing import Any

from firebase_admin import auth
from google.cloud import firestore
from google.cloud.firestore import Client
from google.cloud.firestore_v1.base_query import FieldFilter

from .errors import failed_precondition, not_found
from .firebase import ensure_firebase_app
from .scheduling import utc_now


def _commit_in_chunks(db: Client, operations: list[tuple[str, Any, Any]]) -> None:
    for start in range(0, len(operations), 400):
        batch = db.batch()
        for operation, reference, data in operations[start : start + 400]:
            if operation == "update":
                batch.update(reference, data)
            elif operation == "delete":
                batch.delete(reference)
            else:
                batch.set(reference, data)
        batch.commit()


def ensure_profile(db: Client, user: dict[str, Any], data: dict[str, Any]) -> None:
    uid = str(user["uid"])
    reference = db.collection("users").document(uid)
    existing = reference.get().to_dict() or {}
    now = utc_now()
    reference.set(
        {
            "uid": uid,
            "firstName": data["firstName"].strip(),
            "lastName": data["lastName"].strip(),
            "email": str(user.get("email") or "").lower(),
            "phone": data["phone"].strip(),
            "notificationEnabled": existing.get("notificationEnabled") is True,
            "privacyAcceptedAt": existing.get("privacyAcceptedAt") or now,
            "createdAt": existing.get("createdAt") or now,
            "updatedAt": now,
            "isAdmin": existing.get("isAdmin") is True,
            "isOwner": existing.get("isOwner") is True,
            "role": existing.get("role") or "client",
        },
        merge=True,
    )


def register_device(db: Client, uid: str, token: str, platform: str) -> None:
    token_id = sha256(token.encode("utf-8")).hexdigest()
    now = utc_now()
    db.collection("users").document(uid).collection("devices").document(token_id).set(
        {
            "token": token,
            "platform": platform,
            "updatedAt": now,
            "createdAt": now,
        },
        merge=True,
    )
    db.collection("users").document(uid).set(
        {"notificationEnabled": True, "updatedAt": now},
        merge=True,
    )


def claims_for_role(
    current_claims: dict[str, Any] | None,
    role: str,
) -> dict[str, Any]:
    claims = dict(current_claims or {})
    claims.pop("admin", None)
    claims.pop("owner", None)
    claims.pop("role", None)
    claims["role"] = role
    if role in {"manager", "owner"}:
        claims["admin"] = True
    if role == "owner":
        claims["owner"] = True
    return claims


def set_role(
    db: Client,
    owner_uid: str,
    target_uid: str,
    role: str,
) -> None:
    if owner_uid == target_uid and role != "owner":
        raise failed_precondition("CANNOT_CHANGE_OWN_OWNER_ROLE")
    ensure_firebase_app()
    try:
        target = auth.get_user(target_uid)
    except auth.UserNotFoundError as error:
        raise not_found("USER_NOT_FOUND") from error
    auth.set_custom_user_claims(
        target_uid,
        claims_for_role(target.custom_claims, role),
    )
    auth.revoke_refresh_tokens(target_uid)
    is_owner = role == "owner"
    db.collection("users").document(target_uid).set(
        {
            "role": role,
            "isAdmin": role == "manager" or is_owner,
            "isOwner": is_owner,
            "roleUpdatedAt": utc_now(),
            "roleUpdatedBy": owner_uid,
            "updatedAt": utc_now(),
        },
        merge=True,
    )


def delete_account(db: Client, user: dict[str, Any]) -> None:
    uid = str(user["uid"])
    if user.get("owner") is True:
        raise failed_precondition("OWNER_ACCOUNT_CANNOT_BE_DELETED")
    user_ref = db.collection("users").document(uid)
    operations: list[tuple[str, Any, Any]] = []
    for snapshot in (
        db.collection("appointments")
        .where(filter=FieldFilter("clientId", "==", uid))
        .stream()
    ):
        operations.append(
            (
                "update",
                snapshot.reference,
                {
                    "clientName": "Cliente eliminato",
                    "clientPhone": firestore.DELETE_FIELD,
                    "updatedAt": utc_now(),
                },
            )
        )
    for snapshot in user_ref.collection("devices").stream():
        operations.append(("delete", snapshot.reference, None))
    operations.append(
        (
            "set",
            user_ref,
            {
                "uid": uid,
                "firstName": "",
                "lastName": "",
                "email": "",
                "phone": "",
                "notificationEnabled": False,
                "deletedAt": utc_now(),
                "updatedAt": utc_now(),
                "isAdmin": False,
                "isOwner": False,
                "role": "client",
            },
        )
    )
    _commit_in_chunks(db, operations)
    ensure_firebase_app()
    auth.delete_user(uid)
