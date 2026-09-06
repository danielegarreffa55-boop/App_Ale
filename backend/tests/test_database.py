from __future__ import annotations

from typing import Any

from app.database import ensure_indexes


class _Collection:
    def __init__(self) -> None:
        self.indexes: list[tuple[tuple[Any, ...], dict[str, Any]]] = []

    def create_index(self, *args: Any, **kwargs: Any) -> None:
        self.indexes.append((args, kwargs))


class _DatabaseWithoutTruthValue:
    def __init__(self) -> None:
        self.users = _Collection()
        self.refresh_tokens = _Collection()
        self.auth_tokens = _Collection()
        self.appointments = _Collection()
        self.services = _Collection()
        self.blocks = _Collection()
        self.rate_limits = _Collection()
        self.notification_logs = _Collection()

    def __bool__(self) -> bool:
        raise NotImplementedError("Database objects do not implement truth testing")


def test_ensure_indexes_does_not_truth_test_database() -> None:
    database = _DatabaseWithoutTruthValue()

    ensure_indexes(database)  # type: ignore[arg-type]

    assert database.users.indexes
    assert database.appointments.indexes
    assert database.notification_logs.indexes
