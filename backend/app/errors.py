from __future__ import annotations

from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


async def api_error_handler(_request: Request, error: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=error.status_code,
        content={"error": {"code": error.code, "message": error.message}},
    )


def bad_request(message: str) -> ApiError:
    return ApiError(400, "invalid-argument", message)


def forbidden(message: str) -> ApiError:
    return ApiError(403, "permission-denied", message)


def not_found(message: str) -> ApiError:
    return ApiError(404, "not-found", message)


def failed_precondition(message: str) -> ApiError:
    return ApiError(409, "failed-precondition", message)
