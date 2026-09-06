from __future__ import annotations

from datetime import datetime, timedelta
from types import SimpleNamespace
from typing import Any
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient
import mongomock
import pytest

from app import auth, main, notifications
from app.database import ensure_indexes
from app.scheduling import DEFAULT_OPENING_HOURS, utc_now


@pytest.fixture
def db(monkeypatch: pytest.MonkeyPatch) -> Any:
    target = mongomock.MongoClient(tz_aware=True).agh_test
    ensure_indexes(target)
    monkeypatch.setattr(main, "database", lambda: target)
    monkeypatch.setattr(auth, "database", lambda: target)
    return target


@pytest.fixture
def client() -> TestClient:
    return TestClient(main.app)


def _registration() -> dict[str, Any]:
    return {
        "firstName": "Mario",
        "lastName": "Rossi",
        "email": "mario@example.it",
        "phone": "+393331234567",
        "password": "Correct-Horse-42!",
        "privacyAccepted": True,
    }


def _register(client: TestClient, email: str) -> dict[str, Any]:
    payload = {**_registration(), "email": email}
    response = client.post("/v1/auth/register", json=payload)
    assert response.status_code == 201
    return response.json()


def _authorization(session: dict[str, Any]) -> dict[str, str]:
    return {"Authorization": f"Bearer {session['accessToken']}"}


def _open_start() -> datetime:
    zone = ZoneInfo("Europe/Rome")
    day = (utc_now().astimezone(zone) + timedelta(days=7)).date()
    while day.weekday() == 6:
        day += timedelta(days=1)
    return datetime(day.year, day.month, day.day, 10, 0, tzinfo=zone)


def _seed_booking_data(db: Any) -> None:
    now = utc_now()
    db.services.insert_one(
        {
            "_id": "taglio",
            "name": "Taglio",
            "category": "Capelli",
            "description": "",
            "durationMinutes": 45,
            "bufferMinutes": 0,
            "priceCents": 3500,
            "priceFrom": False,
            "operatorIds": ["alessio"],
            "active": True,
            "displayOrder": 0,
            "createdAt": now,
            "updatedAt": now,
        }
    )
    db.studio.insert_one(
        {
            "_id": "config",
            "timezone": "Europe/Rome",
            "openingHours": DEFAULT_OPENING_HOURS,
            "minimumLeadMinutes": 0,
            "bookingHorizonDays": 90,
            "cancellationNoticeHours": 24,
        }
    )


def test_health_endpoint(client: TestClient) -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "alessio-garreffa-hair-api",
    }


def test_protected_endpoint_requires_bearer_token(client: TestClient) -> None:
    response = client.get(
        "/v1/availability",
        params={"serviceId": "service", "date": "2026-09-07"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["message"] == "AUTH_REQUIRED"


def test_register_login_refresh_and_me(client: TestClient, db: Any) -> None:
    registered = client.post("/v1/auth/register", json=_registration())
    assert registered.status_code == 201
    assert registered.json()["user"]["role"] == "client"
    assert registered.json()["user"]["emailVerified"] is False

    logged_in = client.post(
        "/v1/auth/login",
        json={"email": "mario@example.it", "password": "Correct-Horse-42!"},
    )
    assert logged_in.status_code == 200
    session = logged_in.json()
    me = client.get(
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {session['accessToken']}"},
    )
    assert me.status_code == 200
    assert me.json()["user"]["displayName"] == "Mario Rossi"

    refreshed = client.post(
        "/v1/auth/refresh", json={"refreshToken": session["refreshToken"]}
    )
    assert refreshed.status_code == 200
    replay = client.post(
        "/v1/auth/refresh", json={"refreshToken": session["refreshToken"]}
    )
    assert replay.status_code == 401
    replay_revokes_family = client.post(
        "/v1/auth/refresh",
        json={"refreshToken": refreshed.json()["refreshToken"]},
    )
    assert replay_revokes_family.status_code == 401


def test_duplicate_email_and_wrong_password_are_rejected(
    client: TestClient, db: Any
) -> None:
    assert client.post("/v1/auth/register", json=_registration()).status_code == 201
    duplicate = client.post("/v1/auth/register", json=_registration())
    assert duplicate.status_code == 409
    wrong = client.post(
        "/v1/auth/login",
        json={"email": "mario@example.it", "password": "wrong"},
    )
    assert wrong.status_code == 401
    assert wrong.json()["error"]["message"] == "INVALID_CREDENTIALS"


def test_owner_route_enforces_role(client: TestClient, db: Any) -> None:
    session = client.post("/v1/auth/register", json=_registration()).json()
    user_id = session["user"]["id"]
    forbidden = client.put(
        f"/v1/owner/users/{user_id}/role",
        json={"role": "manager"},
        headers={"Authorization": f"Bearer {session['accessToken']}"},
    )
    assert forbidden.status_code == 403


def test_password_hash_is_not_exposed(client: TestClient, db: Any) -> None:
    response = client.post("/v1/auth/register", json=_registration())
    assert "password" not in str(response.json()).lower()
    stored = db.users.find_one({"emailLower": "mario@example.it"})
    assert stored is not None
    assert stored["passwordHash"].startswith("$argon2id$")


def test_clients_can_request_same_slot_but_only_admin_can_confirm_one(
    client: TestClient, db: Any
) -> None:
    _seed_booking_data(db)
    first = _register(client, "first@example.it")
    second = _register(client, "second@example.it")
    db.users.update_many({}, {"$set": {"emailVerified": True}})
    start = _open_start().isoformat()

    first_request = client.post(
        "/v1/appointments",
        json={"serviceId": "taglio", "requestedStartAt": start},
        headers=_authorization(first),
    )
    second_request = client.post(
        "/v1/appointments",
        json={"serviceId": "taglio", "requestedStartAt": start},
        headers=_authorization(second),
    )
    assert first_request.status_code == 201
    assert second_request.status_code == 201

    db.users.update_one({"_id": first["user"]["id"]}, {"$set": {"role": "manager"}})
    accepted = client.post(
        f"/v1/admin/appointments/{first_request.json()['appointmentId']}/accept",
        headers=_authorization(first),
    )
    conflict = client.post(
        f"/v1/admin/appointments/{second_request.json()['appointmentId']}/accept",
        headers=_authorization(first),
    )
    assert accepted.status_code == 200
    assert conflict.status_code == 409
    assert conflict.json()["error"]["message"] == "SLOT_UNAVAILABLE"


def test_agenda_block_warns_but_does_not_prevent_confirmation(
    client: TestClient, db: Any
) -> None:
    _seed_booking_data(db)
    session = _register(client, "manager@example.it")
    user_id = session["user"]["id"]
    db.users.update_one(
        {"_id": user_id},
        {"$set": {"role": "manager", "emailVerified": True}},
    )
    start = _open_start()
    appointment = client.post(
        "/v1/appointments",
        json={"serviceId": "taglio", "requestedStartAt": start.isoformat()},
        headers=_authorization(session),
    )
    block = client.post(
        "/v1/admin/blocks",
        json={
            "startAt": start.isoformat(),
            "endAt": (start + timedelta(hours=1)).isoformat(),
            "reason": "Formazione",
        },
        headers=_authorization(session),
    )
    accepted = client.post(
        f"/v1/admin/appointments/{appointment.json()['appointmentId']}/accept",
        headers=_authorization(session),
    )
    assert appointment.status_code == 201
    assert block.status_code == 201
    assert accepted.status_code == 200


def test_unverified_email_cannot_create_appointment(
    client: TestClient, db: Any
) -> None:
    _seed_booking_data(db)
    session = _register(client, "unverified@example.it")
    response = client.post(
        "/v1/appointments",
        json={
            "serviceId": "taglio",
            "requestedStartAt": _open_start().isoformat(),
        },
        headers=_authorization(session),
    )
    assert response.status_code == 409
    assert response.json()["error"]["message"] == "EMAIL_NOT_VERIFIED"


def test_email_verification_and_password_reset_are_single_use(
    client: TestClient, db: Any
) -> None:
    session = _register(client, "account-actions@example.it")
    user_id = session["user"]["id"]
    verification = auth.create_opaque_token(
        db, user_id, "verify-email", timedelta(hours=1)
    )
    verified = client.post("/v1/auth/verify-email", json={"token": verification})
    replayed_verification = client.post(
        "/v1/auth/verify-email", json={"token": verification}
    )
    assert verified.status_code == 200
    assert replayed_verification.status_code == 400
    assert db.users.find_one({"_id": user_id})["emailVerified"] is True

    reset_token = auth.create_opaque_token(
        db, user_id, "reset-password", timedelta(minutes=30)
    )
    reset = client.post(
        "/v1/auth/reset-password",
        json={"token": reset_token, "newPassword": "New-Password-84!"},
    )
    replayed_reset = client.post(
        "/v1/auth/reset-password",
        json={"token": reset_token, "newPassword": "Another-Password-85!"},
    )
    old_session = client.get("/v1/auth/me", headers=_authorization(session))
    new_login = client.post(
        "/v1/auth/login",
        json={
            "email": "account-actions@example.it",
            "password": "New-Password-84!",
        },
    )
    assert reset.status_code == 200
    assert replayed_reset.status_code == 400
    assert old_session.status_code == 401
    assert new_login.status_code == 200


def test_reminder_endpoint_rejects_invalid_scheduler_credentials(
    client: TestClient,
) -> None:
    response = client.post("/internal/reminders", headers={"X-Cron-Secret": "wrong"})
    assert response.status_code == 403
    assert response.json()["error"]["message"] == "CRON_AUTH_REQUIRED"


def test_failed_push_is_retried_with_same_idempotency_key(
    db: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        notifications,
        "settings",
        lambda: SimpleNamespace(
            onesignal_app_id="00000000-0000-0000-0000-000000000000",
            onesignal_api_key="api-key",
        ),
    )
    payloads: list[dict[str, Any]] = []

    class SuccessResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, str]:
            return {"id": "11111111-1111-1111-1111-111111111111"}

    def fake_post(*_args: Any, **kwargs: Any) -> SuccessResponse:
        payloads.append(kwargs["json"])
        if len(payloads) == 1:
            raise TimeoutError("temporary")
        return SuccessResponse()

    monkeypatch.setattr(notifications.httpx, "post", fake_post)
    first = notifications.send_to_user(
        db,
        "user-1",
        "notification-1",
        "Titolo",
        "Messaggio",
        {"type": "confirmed", "appointmentId": "appointment-1"},
    )
    db.notification_logs.update_one(
        {"_id": "notification-1"},
        {"$set": {"claimedAt": utc_now() - timedelta(minutes=11)}},
    )
    retried = notifications.retry_failed(db)

    assert first is False
    assert retried == 1
    assert len(payloads) == 2
    assert payloads[0]["idempotency_key"] == payloads[1]["idempotency_key"]
    assert db.notification_logs.find_one({"_id": "notification-1"})["status"] == "SENT"
