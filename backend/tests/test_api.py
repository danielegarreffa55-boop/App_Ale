from fastapi.testclient import TestClient

from app.main import app


def test_health_endpoint() -> None:
    response = TestClient(app).get("/healthz")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "alessio-garreffa-hair-api",
    }


def test_protected_endpoint_requires_bearer_token() -> None:
    response = TestClient(app).get(
        "/v1/availability",
        params={"serviceId": "service", "date": "2026-09-07"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["message"] == "AUTH_REQUIRED"
