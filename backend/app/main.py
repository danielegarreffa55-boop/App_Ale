from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta
import logging
import secrets
from typing import Annotated, Any
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token as google_id_token
from pymongo import ASCENDING, DESCENDING

from . import accounts, appointments, auth, calendar_sync, mail, notifications
from .auth import User, admin_user, current_user, owner_user
from .config import settings
from .database import database, ensure_indexes, mongo_client, public_document
from .errors import ApiError, api_error_handler, forbidden, not_found
from .models import (
    AppointmentRequestInput,
    BlockInput,
    CounterProposalInput,
    CounterResponseInput,
    ForgotPasswordInput,
    LoginInput,
    ManualAppointmentInput,
    ProfileInput,
    RefreshInput,
    RegisterInput,
    RejectInput,
    ResetPasswordInput,
    RescheduleInput,
    RoleInput,
    ServiceInput,
    StudioConfigInput,
    VerifyEmailInput,
)
from .scheduling import utc_now

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    mongo_client().admin.command("ping")
    ensure_indexes()
    yield
    mongo_client().close()


app = FastAPI(
    title="Alessio Garreffa Hair API",
    version="2.0.0",
    docs_url="/docs" if settings().environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)
app.add_exception_handler(ApiError, api_error_handler)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(
    _request: Request, _error: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content={"error": {"code": "invalid-argument", "message": "INVALID_INPUT"}},
    )


@app.exception_handler(Exception)
async def unexpected_error_handler(_request: Request, error: Exception) -> JSONResponse:
    logger.exception("Unhandled API error", exc_info=error)
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "internal", "message": "INTERNAL_ERROR"}},
    )


if settings().cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings().cors_origins),
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Cron-Secret"],
    )


def _auth_response(user: User, tokens: dict[str, Any]) -> dict[str, Any]:
    return {**tokens, "user": accounts.public_user(user)}


def _appointment_response(
    document: dict[str, Any], *, include_client: bool = False
) -> dict[str, Any]:
    fields = {
        "clientId",
        "serviceId",
        "serviceName",
        "durationMinutes",
        "bufferMinutes",
        "status",
        "requestedStartAt",
        "requestedEndAt",
        "proposedStartAt",
        "proposedEndAt",
        "confirmedStartAt",
        "confirmedEndAt",
        "createdAt",
        "adminReason",
    }
    if include_client:
        fields.update({"clientName", "clientPhone"})
    return {
        "id": str(document["_id"]),
        **{field: document[field] for field in fields if field in document},
    }


@app.get("/healthz")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "alessio-garreffa-hair-api"}


@app.get("/readyz")
def ready() -> dict[str, str]:
    mongo_client().admin.command("ping")
    return {"status": "ready"}


@app.post("/v1/auth/register", status_code=201)
def register(body: RegisterInput) -> dict[str, Any]:
    db = database()
    appointments.rate_limit(db, str(body.email).lower(), "register", 5, 3600)
    user = accounts.register(db, body.model_dump())
    response = _auth_response(user, auth.create_token_pair(db, user))
    return response


@app.post("/v1/auth/login")
def login(body: LoginInput) -> dict[str, Any]:
    db = database()
    appointments.rate_limit(db, str(body.email).lower(), "login", 10, 900)
    user = accounts.authenticate(db, str(body.email), body.password)
    return _auth_response(user, auth.create_token_pair(db, user))


@app.post("/v1/auth/refresh")
def refresh(body: RefreshInput) -> dict[str, Any]:
    user, tokens = auth.rotate_refresh_token(database(), body.refreshToken)
    return _auth_response(user, tokens)


@app.post("/v1/auth/logout")
def logout(body: RefreshInput) -> dict[str, bool]:
    auth.revoke_refresh_token(database(), body.refreshToken)
    return {"ok": True}


@app.get("/v1/auth/me")
def me(user: Annotated[User, Depends(current_user)]) -> dict[str, Any]:
    return {"user": accounts.public_user(user)}


@app.post("/v1/auth/verify-email")
def verify_email(body: VerifyEmailInput) -> dict[str, Any]:
    user = accounts.verify_email(database(), body.token)
    return {"ok": True, "user": accounts.public_user(user)}


@app.post("/v1/auth/resend-verification")
def resend_verification(user: Annotated[User, Depends(current_user)]) -> dict[str, Any]:
    if user.get("emailVerified") is True:
        return {"ok": True}
    appointments.rate_limit(database(), str(user["_id"]), "resendVerification", 3, 3600)
    token = auth.create_opaque_token(
        database(), str(user["_id"]), "verify-email", timedelta(hours=24)
    )
    mail.send_verification(user["email"], token)
    response: dict[str, Any] = {"ok": True}
    if settings().expose_dev_tokens and settings().environment != "production":
        response["verificationToken"] = token
    return response


@app.post("/v1/auth/forgot-password")
def forgot_password(body: ForgotPasswordInput) -> dict[str, Any]:
    db = database()
    email = str(body.email).lower()
    appointments.rate_limit(db, email, "forgotPassword", 3, 3600)
    user = db.users.find_one({"emailLower": email, "deletedAt": None})
    response: dict[str, Any] = {"ok": True}
    if user:
        token = auth.create_opaque_token(
            db, str(user["_id"]), "reset-password", timedelta(minutes=30)
        )
        mail.send_password_reset(user["email"], token)
        if settings().expose_dev_tokens and settings().environment != "production":
            response["resetToken"] = token
    return response


@app.post("/v1/auth/reset-password")
def reset_password(body: ResetPasswordInput) -> dict[str, bool]:
    db = database()
    user = auth.consume_opaque_token(db, body.token, "reset-password")
    db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "passwordHash": auth.hash_password(body.newPassword),
                "updatedAt": utc_now(),
            },
            "$inc": {"sessionVersion": 1},
        },
    )
    db.refresh_tokens.delete_many({"userId": str(user["_id"])})
    return {"ok": True}


@app.patch("/v1/profile")
def save_profile(
    body: ProfileInput, user: Annotated[User, Depends(current_user)]
) -> dict[str, Any]:
    updated = accounts.update_profile(database(), str(user["_id"]), body.model_dump())
    return {"ok": True, "user": accounts.public_user(updated)}


@app.delete("/v1/account")
def delete_account(user: Annotated[User, Depends(current_user)]) -> dict[str, bool]:
    accounts.delete_account(database(), user)
    return {"ok": True}


@app.put("/v1/owner/users/{target_user_id}/role")
def set_user_role(
    target_user_id: str,
    body: RoleInput,
    user: Annotated[User, Depends(owner_user)],
) -> dict[str, Any]:
    accounts.set_role(database(), str(user["_id"]), target_user_id, body.role)
    return {"ok": True, "role": body.role}


@app.get("/v1/services")
def list_services(
    user: Annotated[User, Depends(current_user)],
    include_inactive: Annotated[bool, Query(alias="includeInactive")] = False,
) -> dict[str, Any]:
    if include_inactive and user.get("role") not in {"manager", "owner"}:
        raise forbidden("ADMIN_REQUIRED")
    query = {} if include_inactive else {"active": True}
    documents = database().services.find(query).sort("displayOrder", ASCENDING)
    return {"items": [public_document(item) for item in documents]}


@app.get("/v1/studio-config")
def studio_config(_user: Annotated[User, Depends(current_user)]) -> dict[str, Any]:
    document = database().studio.find_one({"_id": "config"}) or {}
    document.pop("_id", None)
    return {"config": document}


@app.get("/v1/appointments")
def client_appointments(user: Annotated[User, Depends(current_user)]) -> dict[str, Any]:
    documents = (
        database()
        .appointments.find({"clientId": str(user["_id"])})
        .sort("createdAt", DESCENDING)
        .limit(100)
    )
    return {"items": [_appointment_response(item) for item in documents]}


@app.get("/v1/admin/appointments")
def admin_appointments(
    user: Annotated[User, Depends(admin_user)],
    start_at: Annotated[datetime | None, Query(alias="startAt")] = None,
    end_at: Annotated[datetime | None, Query(alias="endAt")] = None,
) -> dict[str, Any]:
    query: dict[str, Any] = {}
    sort_field = "createdAt"
    sort_order = DESCENDING
    if start_at is not None and end_at is not None:
        query["confirmedStartAt"] = {"$gte": start_at, "$lt": end_at}
        sort_field = "confirmedStartAt"
        sort_order = ASCENDING
    documents = (
        database().appointments.find(query).sort(sort_field, sort_order).limit(500)
    )
    return {
        "items": [
            _appointment_response(item, include_client=True) for item in documents
        ]
    }


@app.get("/v1/admin/blocks")
def admin_blocks(_user: Annotated[User, Depends(admin_user)]) -> dict[str, Any]:
    documents = (
        database().blocks.find({"active": True}).sort("startAt", ASCENDING).limit(500)
    )
    return {"items": [public_document(item) for item in documents]}


@app.get("/v1/admin/users")
def admin_users(_user: Annotated[User, Depends(admin_user)]) -> dict[str, Any]:
    documents = (
        database()
        .users.find({"deletedAt": None})
        .sort("lastName", ASCENDING)
        .limit(1000)
    )
    return {"items": [accounts.public_user(item) for item in documents]}


@app.get("/v1/availability")
def get_availability(
    service_id: Annotated[str, Query(alias="serviceId", min_length=1, max_length=200)],
    day: Annotated[str, Query(alias="date", pattern=r"^\d{4}-\d{2}-\d{2}$")],
    user: Annotated[User, Depends(current_user)],
) -> dict[str, Any]:
    return {
        "slots": appointments.availability(
            database(), str(user["_id"]), service_id, date.fromisoformat(day)
        )
    }


@app.post("/v1/appointments", status_code=201)
def create_appointment_request(
    body: AppointmentRequestInput, user: Annotated[User, Depends(current_user)]
) -> dict[str, str]:
    db = database()
    appointment_id = appointments.create_request(
        db, user, body.serviceId, body.requestedStartAt
    )
    notifications.send_to_admins(
        db,
        f"appointment_created_{appointment_id}",
        "Nuova richiesta",
        "È arrivata una nuova richiesta di appuntamento.",
        {"type": "appointment_created", "appointmentId": appointment_id},
    )
    return {"appointmentId": appointment_id}


@app.post("/v1/appointments/{appointment_id}/counter-response")
def counter_response(
    appointment_id: str,
    body: CounterResponseInput,
    user: Annotated[User, Depends(current_user)],
) -> dict[str, Any]:
    db = database()
    status, appointment = appointments.client_counter_response(
        db, str(user["_id"]), appointment_id, body.accept
    )
    if status == "CONFIRMED":
        calendar_sync.sync_event(db, appointment_id, appointment)
    notifications.send_to_admins(
        db,
        f"counter_response_{appointment_id}_{status}",
        "Risposta alla controproposta",
        "Il cliente ha risposto alla controproposta.",
        {"type": "counter_response", "appointmentId": appointment_id},
    )
    return {"ok": True, "status": status}


@app.post("/v1/appointments/{appointment_id}/cancel")
def cancel_appointment(
    appointment_id: str, user: Annotated[User, Depends(current_user)]
) -> dict[str, bool]:
    db = database()
    appointment = appointments.cancel(db, user, appointment_id)
    if appointment.get("confirmedStartAt"):
        calendar_sync.delete_event(db, appointment_id, appointment)
    if user.get("role") in {"manager", "owner"}:
        notifications.send_to_user(
            db,
            appointment.get("clientId", ""),
            f"cancelled_{appointment_id}_client",
            "Appuntamento annullato",
            "Lo studio ha annullato l'appuntamento.",
            {"type": "cancelled", "appointmentId": appointment_id},
        )
    else:
        notifications.send_to_admins(
            db,
            f"cancelled_{appointment_id}",
            "Appuntamento annullato",
            "Il cliente ha annullato l'appuntamento.",
            {"type": "cancelled", "appointmentId": appointment_id},
        )
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/accept")
def accept_appointment(
    appointment_id: str, user: Annotated[User, Depends(admin_user)]
) -> dict[str, bool]:
    db = database()
    appointment = appointments.admin_accept(db, str(user["_id"]), appointment_id)
    calendar_sync.sync_event(db, appointment_id, appointment)
    notifications.send_to_user(
        db,
        appointment["clientId"],
        f"accepted_{appointment_id}",
        "Appuntamento confermato",
        "La tua richiesta è stata confermata.",
        {"type": "confirmed", "appointmentId": appointment_id},
    )
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/reject")
def reject_appointment(
    appointment_id: str,
    body: RejectInput,
    user: Annotated[User, Depends(admin_user)],
) -> dict[str, bool]:
    db = database()
    appointment = appointments.admin_reject(
        db, str(user["_id"]), appointment_id, body.reason
    )
    notifications.send_to_user(
        db,
        appointment["clientId"],
        f"rejected_{appointment_id}",
        "Richiesta non accettata",
        "Lo studio non ha potuto confermare la richiesta.",
        {"type": "rejected", "appointmentId": appointment_id},
    )
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/counter-proposal")
def counter_proposal(
    appointment_id: str,
    body: CounterProposalInput,
    user: Annotated[User, Depends(admin_user)],
) -> dict[str, bool]:
    db = database()
    appointment = appointments.admin_counter_propose(
        db, str(user["_id"]), appointment_id, body.proposedStartAt
    )
    notifications.send_to_user(
        db,
        appointment["clientId"],
        f"counter_{appointment_id}_{int(body.proposedStartAt.timestamp())}",
        "Nuova proposta di orario",
        "Lo studio ti ha proposto un nuovo orario.",
        {"type": "counter_proposal", "appointmentId": appointment_id},
    )
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/complete")
def complete_appointment(
    appointment_id: str, user: Annotated[User, Depends(admin_user)]
) -> dict[str, bool]:
    appointments.admin_complete(database(), str(user["_id"]), appointment_id)
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/reschedule")
def reschedule_appointment(
    appointment_id: str,
    body: RescheduleInput,
    user: Annotated[User, Depends(admin_user)],
) -> dict[str, bool]:
    db = database()
    appointment = appointments.admin_reschedule(
        db, str(user["_id"]), appointment_id, body.startAt
    )
    calendar_sync.sync_event(db, appointment_id, appointment)
    notifications.send_to_user(
        db,
        appointment["clientId"],
        f"rescheduled_{appointment_id}_{int(body.startAt.timestamp())}",
        "Appuntamento spostato",
        "Lo studio ha aggiornato l'orario del tuo appuntamento.",
        {"type": "rescheduled", "appointmentId": appointment_id},
    )
    return {"ok": True}


@app.post("/v1/admin/appointments", status_code=201)
def create_manual_appointment(
    body: ManualAppointmentInput, user: Annotated[User, Depends(admin_user)]
) -> dict[str, str]:
    db = database()
    appointment_id, appointment = appointments.admin_create_appointment(
        db, str(user["_id"]), body.clientId, body.serviceId, body.startAt
    )
    calendar_sync.sync_event(db, appointment_id, appointment)
    notifications.send_to_user(
        db,
        appointment["clientId"],
        f"manual_{appointment_id}",
        "Nuovo appuntamento",
        "Lo studio ha inserito un nuovo appuntamento.",
        {"type": "confirmed", "appointmentId": appointment_id},
    )
    return {"appointmentId": appointment_id}


@app.post("/v1/admin/blocks", status_code=201)
def create_block(
    body: BlockInput, user: Annotated[User, Depends(admin_user)]
) -> dict[str, str]:
    block_id = appointments.admin_create_block(
        database(), str(user["_id"]), body.startAt, body.endAt, body.reason
    )
    return {"blockId": block_id}


@app.post("/v1/admin/services", status_code=201)
def create_service(
    body: ServiceInput, _user: Annotated[User, Depends(admin_user)]
) -> dict[str, str]:
    service_id = str(uuid4())
    now = utc_now()
    database().services.insert_one(
        {"_id": service_id, **body.model_dump(), "createdAt": now, "updatedAt": now}
    )
    return {"serviceId": service_id}


@app.put("/v1/admin/services/{service_id}")
def update_service(
    service_id: str,
    body: ServiceInput,
    _user: Annotated[User, Depends(admin_user)],
) -> dict[str, bool]:
    result = database().services.update_one(
        {"_id": service_id},
        {"$set": {**body.model_dump(), "updatedAt": utc_now()}},
        upsert=False,
    )
    if result.matched_count != 1:
        raise not_found("SERVICE_NOT_FOUND")
    return {"ok": True}


@app.patch("/v1/admin/studio-config")
def update_studio_config(
    body: StudioConfigInput, _user: Annotated[User, Depends(admin_user)]
) -> dict[str, bool]:
    changes = body.model_dump(exclude_none=True)
    changes["updatedAt"] = utc_now()
    database().studio.update_one({"_id": "config"}, {"$set": changes}, upsert=True)
    return {"ok": True}


@app.post("/internal/reminders")
def scheduled_reminders(
    cron_secret: Annotated[str | None, Header(alias="X-Cron-Secret")] = None,
    authorization: Annotated[str | None, Header()] = None,
) -> dict[str, int]:
    config = settings()
    secret_valid = bool(
        cron_secret and secrets.compare_digest(cron_secret, config.cron_secret)
    )
    oidc_valid = False
    if (
        not secret_valid
        and authorization
        and authorization.startswith("Bearer ")
        and config.cron_oidc_audience
        and config.cron_service_account
    ):
        try:
            claims = google_id_token.verify_oauth2_token(
                authorization.removeprefix("Bearer ").strip(),
                GoogleAuthRequest(),
                audience=config.cron_oidc_audience,
            )
            oidc_valid = (
                claims.get("email") == config.cron_service_account
                and claims.get("email_verified") is True
            )
        except (ValueError, OSError):
            oidc_valid = False
    if not secret_valid and not oidc_valid:
        raise forbidden("CRON_AUTH_REQUIRED")
    db = database()
    return {
        "remindersSent": notifications.send_reminders(db),
        "notificationsRetried": notifications.retry_failed(db),
    }
