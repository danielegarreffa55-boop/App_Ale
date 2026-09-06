from __future__ import annotations

import logging
from typing import Annotated, Any

from fastapi import Depends, FastAPI, Query
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.cloud import firestore

from . import accounts, appointments, calendar_sync
from .auth import Claims, admin_user, current_user, owner_user
from .config import settings
from .errors import ApiError, api_error_handler
from .firebase import database
from .models import (
    AppointmentRequestInput,
    BlockInput,
    CounterProposalInput,
    CounterResponseInput,
    DeviceTokenInput,
    ManualAppointmentInput,
    ProfileInput,
    RejectInput,
    RescheduleInput,
    RoleInput,
    ServiceInput,
    StudioConfigInput,
)
from .scheduling import utc_now

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Alessio Garreffa Hair API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url=None,
)
app.add_exception_handler(ApiError, api_error_handler)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(
    _request: Any,
    _error: RequestValidationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content={"error": {"code": "invalid-argument", "message": "INVALID_INPUT"}},
    )


@app.exception_handler(Exception)
async def unexpected_error_handler(_request: Any, error: Exception) -> JSONResponse:
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
        allow_headers=["Authorization", "Content-Type"],
    )


@app.get("/healthz")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "alessio-garreffa-hair-api"}


@app.get("/readyz")
def ready(_user: Annotated[Claims, Depends(admin_user)]) -> dict[str, str]:
    database().collection("studio").document("config").get()
    return {"status": "ready", "project": settings().project_id}


@app.post("/v1/profile")
def save_profile(
    body: ProfileInput,
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, bool]:
    appointments.rate_limit(database(), str(user["uid"]), "profile", 5)
    accounts.ensure_profile(database(), user, body.model_dump())
    return {"ok": True}


@app.post("/v1/devices")
def register_device(
    body: DeviceTokenInput,
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, bool]:
    uid = str(user["uid"])
    appointments.rate_limit(database(), uid, "device", 20)
    accounts.register_device(database(), uid, body.token, body.platform)
    return {"ok": True}


@app.delete("/v1/account")
def delete_account(
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, bool]:
    uid = str(user["uid"])
    appointments.rate_limit(database(), uid, "deleteAccount", 2, 3600)
    accounts.delete_account(database(), user)
    return {"ok": True}


@app.put("/v1/owner/users/{target_uid}/role")
def set_user_role(
    target_uid: str,
    body: RoleInput,
    user: Annotated[Claims, Depends(owner_user)],
) -> dict[str, Any]:
    uid = str(user["uid"])
    appointments.rate_limit(database(), uid, "setUserRole", 30)
    accounts.set_role(database(), uid, target_uid, body.role)
    return {"ok": True, "role": body.role}


@app.get("/v1/availability")
def get_availability(
    service_id: Annotated[str, Query(alias="serviceId", min_length=1, max_length=200)],
    day: Annotated[str, Query(alias="date", pattern=r"^\d{4}-\d{2}-\d{2}$")],
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, Any]:
    from datetime import date

    return {
        "slots": appointments.availability(
            database(),
            str(user["uid"]),
            service_id,
            date.fromisoformat(day),
        )
    }


@app.post("/v1/appointments", status_code=201)
def create_appointment_request(
    body: AppointmentRequestInput,
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, str]:
    appointment_id = appointments.create_request(
        database(), user, body.serviceId, body.requestedStartAt
    )
    return {"appointmentId": appointment_id}


@app.post("/v1/appointments/{appointment_id}/counter-response")
def counter_response(
    appointment_id: str,
    body: CounterResponseInput,
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, Any]:
    status, appointment = appointments.client_counter_response(
        database(), str(user["uid"]), appointment_id, body.accept
    )
    if appointment:
        calendar_sync.sync_event(database(), appointment_id, appointment)
    return {"ok": True, "status": status}


@app.post("/v1/appointments/{appointment_id}/cancel")
def cancel_appointment(
    appointment_id: str,
    user: Annotated[Claims, Depends(current_user)],
) -> dict[str, bool]:
    appointment = appointments.cancel(database(), user, appointment_id)
    if appointment.get("confirmedStartAt"):
        calendar_sync.delete_event(database(), appointment_id, appointment)
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/accept")
def accept_appointment(
    appointment_id: str,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    appointment = appointments.admin_accept(
        database(), str(user["uid"]), appointment_id
    )
    calendar_sync.sync_event(database(), appointment_id, appointment)
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/reject")
def reject_appointment(
    appointment_id: str,
    body: RejectInput,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    appointments.admin_reject(database(), str(user["uid"]), appointment_id, body.reason)
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/counter-proposal")
def counter_proposal(
    appointment_id: str,
    body: CounterProposalInput,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    appointments.admin_counter_propose(
        database(), str(user["uid"]), appointment_id, body.proposedStartAt
    )
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/complete")
def complete_appointment(
    appointment_id: str,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    appointments.admin_complete(database(), str(user["uid"]), appointment_id)
    return {"ok": True}


@app.post("/v1/admin/appointments/{appointment_id}/reschedule")
def reschedule_appointment(
    appointment_id: str,
    body: RescheduleInput,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    appointment = appointments.admin_reschedule(
        database(), str(user["uid"]), appointment_id, body.startAt
    )
    calendar_sync.sync_event(database(), appointment_id, appointment)
    return {"ok": True}


@app.post("/v1/admin/appointments", status_code=201)
def create_manual_appointment(
    body: ManualAppointmentInput,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, str]:
    appointment_id, appointment = appointments.admin_create_appointment(
        database(),
        str(user["uid"]),
        body.clientId,
        body.serviceId,
        body.startAt,
    )
    calendar_sync.sync_event(database(), appointment_id, appointment)
    return {"appointmentId": appointment_id}


@app.post("/v1/admin/blocks", status_code=201)
def create_block(
    body: BlockInput,
    user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, str]:
    block_id = appointments.admin_create_block(
        database(), str(user["uid"]), body.startAt, body.endAt, body.reason
    )
    return {"blockId": block_id}


@app.post("/v1/admin/services", status_code=201)
def create_service(
    body: ServiceInput,
    _user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, str]:
    reference = database().collection("services").document()
    reference.create(
        {**body.model_dump(), "createdAt": utc_now(), "updatedAt": utc_now()}
    )
    return {"serviceId": reference.id}


@app.put("/v1/admin/services/{service_id}")
def update_service(
    service_id: str,
    body: ServiceInput,
    _user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    database().collection("services").document(service_id).set(
        {**body.model_dump(), "updatedAt": utc_now()}, merge=True
    )
    return {"ok": True}


@app.patch("/v1/admin/studio-config")
def update_studio_config(
    body: StudioConfigInput,
    _user: Annotated[Claims, Depends(admin_user)],
) -> dict[str, bool]:
    changes = body.model_dump(exclude_none=True)
    changes["updatedAt"] = firestore.SERVER_TIMESTAMP
    database().collection("studio").document("config").set(changes, merge=True)
    return {"ok": True}
