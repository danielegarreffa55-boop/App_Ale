from __future__ import annotations

from datetime import datetime
from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class RegisterInput(StrictModel):
    firstName: str = Field(min_length=1, max_length=80, pattern=r".*\S.*")
    lastName: str = Field(min_length=1, max_length=80, pattern=r".*\S.*")
    email: EmailStr
    phone: str = Field(min_length=5, max_length=30, pattern=r".*\S.*")
    password: str = Field(min_length=8, max_length=128)
    privacyAccepted: Literal[True]


class LoginInput(StrictModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshInput(StrictModel):
    refreshToken: str = Field(min_length=40, max_length=4096)


class VerifyEmailInput(StrictModel):
    token: str = Field(min_length=32, max_length=512)


class ForgotPasswordInput(StrictModel):
    email: EmailStr


class ResetPasswordInput(StrictModel):
    token: str = Field(min_length=32, max_length=512)
    newPassword: str = Field(min_length=8, max_length=128)


class ProfileInput(StrictModel):
    firstName: str = Field(min_length=1, max_length=80, pattern=r".*\S.*")
    lastName: str = Field(min_length=1, max_length=80, pattern=r".*\S.*")
    phone: str = Field(min_length=5, max_length=30, pattern=r".*\S.*")


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
    reason: str = Field(min_length=1, max_length=300, pattern=r".*\S.*")


class ServiceInput(StrictModel):
    name: str = Field(min_length=1, max_length=120, pattern=r".*\S.*")
    category: str = Field(default="", max_length=80)
    description: str = Field(default="", max_length=1000)
    durationMinutes: int = Field(ge=5, le=720)
    bufferMinutes: int = Field(default=0, ge=0, le=240)
    priceCents: int | None = Field(default=None, ge=0, le=10_000_000)
    priceFrom: bool = False
    operatorIds: list[str] = Field(default_factory=list, max_length=50)
    active: bool = True
    displayOrder: int = Field(default=0, ge=0, le=100_000)


def _clock_minutes(value: str) -> int:
    hours, minutes = (int(part) for part in value.split(":"))
    if not 0 <= hours <= 23 or not 0 <= minutes <= 59:
        raise ValueError("invalid clock value")
    return hours * 60 + minutes


class OpeningBreak(StrictModel):
    start: str = Field(pattern=r"^\d{2}:\d{2}$")
    end: str = Field(pattern=r"^\d{2}:\d{2}$")

    @field_validator("start", "end")
    @classmethod
    def valid_clock(cls, value: str) -> str:
        _clock_minutes(value)
        return value

    @model_validator(mode="after")
    def ordered(self) -> "OpeningBreak":
        if _clock_minutes(self.end) <= _clock_minutes(self.start):
            raise ValueError("break end must be after start")
        return self


class OpeningDay(StrictModel):
    enabled: bool
    open: str = Field(pattern=r"^\d{2}:\d{2}$")
    close: str = Field(pattern=r"^\d{2}:\d{2}$")
    breaks: list[OpeningBreak] = Field(default_factory=list)

    @field_validator("open", "close")
    @classmethod
    def valid_clock(cls, value: str) -> str:
        _clock_minutes(value)
        return value

    @model_validator(mode="after")
    def valid_interval(self) -> "OpeningDay":
        opening = _clock_minutes(self.open)
        closing = _clock_minutes(self.close)
        if self.enabled and closing <= opening:
            raise ValueError("closing time must be after opening time")
        for pause in self.breaks:
            if (
                _clock_minutes(pause.start) < opening
                or _clock_minutes(pause.end) > closing
            ):
                raise ValueError("break must stay inside opening hours")
        return self


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

    @field_validator("reminderTime")
    @classmethod
    def valid_reminder_time(cls, value: str | None) -> str | None:
        if value is not None:
            _clock_minutes(value)
        return value

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str | None) -> str | None:
        if value is not None:
            try:
                ZoneInfo(value)
            except ZoneInfoNotFoundError as error:
                raise ValueError("unknown timezone") from error
        return value
