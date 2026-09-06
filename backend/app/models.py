from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ProfileInput(StrictModel):
    firstName: str = Field(min_length=1, max_length=80)
    lastName: str = Field(min_length=1, max_length=80)
    phone: str = Field(min_length=5, max_length=30)
    privacyAccepted: Literal[True]


class DeviceTokenInput(StrictModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android", "iOS", "macOS", "web", "windows", "linux"]


class RoleInput(StrictModel):
    role: Literal["client", "manager", "owner"]


class AppointmentRequestInput(StrictModel):
    serviceId: str = Field(min_length=1, max_length=200)
    requestedStartAt: datetime


class CounterProposalInput(StrictModel):
    proposedStartAt: datetime


class CounterResponseInput(StrictModel):
    accept: bool


class RejectInput(StrictModel):
    reason: str | None = Field(default=None, max_length=500)


class RescheduleInput(StrictModel):
    startAt: datetime


class ManualAppointmentInput(StrictModel):
    clientId: str = Field(min_length=1, max_length=200)
    serviceId: str = Field(min_length=1, max_length=200)
    startAt: datetime


class BlockInput(StrictModel):
    startAt: datetime
    endAt: datetime
    reason: str = Field(max_length=300)


class ServiceInput(StrictModel):
    name: str = Field(min_length=1, max_length=120)
    category: str = Field(default="", max_length=80)
    description: str = Field(default="", max_length=1000)
    durationMinutes: int = Field(ge=5, le=720)
    bufferMinutes: int = Field(default=0, ge=0, le=240)
    priceCents: int | None = Field(default=None, ge=0, le=10_000_000)
    priceFrom: bool = False
    operatorIds: list[str] = Field(default_factory=list, max_length=50)
    active: bool = True
    displayOrder: int = Field(default=0, ge=0, le=100_000)


class OpeningDay(StrictModel):
    enabled: bool
    open: str = Field(pattern=r"^\d{2}:\d{2}$")
    close: str = Field(pattern=r"^\d{2}:\d{2}$")
    breaks: list[dict[str, str]] = Field(default_factory=list)


class StudioConfigInput(StrictModel):
    studioName: str | None = Field(default=None, max_length=120)
    supportEmail: str | None = Field(default=None, max_length=254)
    supportPhone: str | None = Field(default=None, max_length=30)
    address: str | None = Field(default=None, max_length=300)
    timezone: str | None = Field(default=None, max_length=80)
    currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    reminderTime: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}$")
    slotMinutes: int | None = Field(default=None, ge=5, le=120)
    minimumLeadMinutes: int | None = Field(default=None, ge=0, le=43_200)
    bookingHorizonDays: int | None = Field(default=None, ge=1, le=730)
    cancellationNoticeHours: int | None = Field(default=None, ge=0, le=720)
    openingHours: dict[str, OpeningDay] | None = None


class AvailabilityQuery(StrictModel):
    serviceId: str
    day: date
