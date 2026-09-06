from __future__ import annotations

from functools import lru_cache
import os

import firebase_admin
from firebase_admin import firestore
from google.auth.credentials import AnonymousCredentials
from google.cloud.firestore import Client

from .config import settings


def ensure_firebase_app() -> firebase_admin.App:
    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(
            options={"projectId": settings().project_id},
        )


@lru_cache
def database() -> Client:
    ensure_firebase_app()
    if os.getenv("FIRESTORE_EMULATOR_HOST"):
        return Client(
            project=settings().project_id,
            credentials=AnonymousCredentials(),
        )
    return firestore.client()
