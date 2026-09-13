from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


_DEVELOPMENT_JWT_SECRET = "development-only-change-this-jwt-secret-before-production"
_DEVELOPMENT_CRON_SECRET = "development-cron-secret"


def _boolean(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    environment: str
    mongo_uri: str
    mongo_database: str
    mongo_transactions: bool
    jwt_secret: str
    jwt_issuer: str
    access_token_minutes: int
    refresh_token_days: int
    public_app_url: str
    cors_origins: tuple[str, ...]
    timezone: str
    calendar_id: str
    onesignal_app_id: str
    onesignal_api_key: str
    cron_secret: str
    cron_oidc_audience: str
    cron_service_account: str
    smtp_host: str
    smtp_port: int
    smtp_username: str
    smtp_password: str
    smtp_from: str
    smtp_use_tls: bool
    expose_dev_tokens: bool


@lru_cache
def settings() -> Settings:
    environment = os.getenv("APP_ENV", "development").strip().lower()
    jwt_secret = os.getenv(
        "JWT_SECRET",
        _DEVELOPMENT_JWT_SECRET,
    )
    cron_secret = os.getenv("CRON_SECRET", _DEVELOPMENT_CRON_SECRET)
    origins = tuple(
        item.strip()
        for item in os.getenv("CORS_ORIGINS", "").split(",")
        if item.strip()
    )
    result = Settings(
        environment=environment,
        mongo_uri=os.getenv("MONGODB_URI", "mongodb://127.0.0.1:27017"),
        mongo_database=os.getenv("MONGODB_DATABASE", "alessio_garreffa_hair"),
        mongo_transactions=_boolean(
            "MONGODB_TRANSACTIONS",
            default=environment == "production",
        ),
        jwt_secret=jwt_secret,
        jwt_issuer=os.getenv("JWT_ISSUER", "alessio-garreffa-hair-api"),
        access_token_minutes=int(os.getenv("ACCESS_TOKEN_MINUTES", "15")),
        refresh_token_days=int(os.getenv("REFRESH_TOKEN_DAYS", "30")),
        public_app_url=os.getenv("PUBLIC_APP_URL", "http://localhost:8080"),
        cors_origins=origins,
        timezone=os.getenv("APP_TIMEZONE", "Europe/Rome"),
        calendar_id=os.getenv("GOOGLE_CALENDAR_ID", ""),
        onesignal_app_id=os.getenv("ONESIGNAL_APP_ID", ""),
        onesignal_api_key=os.getenv("ONESIGNAL_API_KEY", ""),
        cron_secret=cron_secret,
        cron_oidc_audience=os.getenv("CRON_OIDC_AUDIENCE", ""),
        cron_service_account=os.getenv("CRON_SERVICE_ACCOUNT", ""),
        smtp_host=os.getenv("SMTP_HOST", ""),
        smtp_port=int(os.getenv("SMTP_PORT", "587")),
        smtp_username=os.getenv("SMTP_USERNAME", ""),
        smtp_password=os.getenv("SMTP_PASSWORD", ""),
        smtp_from=os.getenv("SMTP_FROM", ""),
        smtp_use_tls=_boolean("SMTP_USE_TLS", default=True),
        expose_dev_tokens=_boolean("EXPOSE_DEV_TOKENS", default=False),
    )
    if environment == "production":
        if jwt_secret == _DEVELOPMENT_JWT_SECRET or len(jwt_secret.encode()) < 32:
            raise RuntimeError(
                "JWT_SECRET must be a unique value of at least 32 bytes in production"
            )
        strong_cron_secret = (
            cron_secret != _DEVELOPMENT_CRON_SECRET and len(cron_secret.encode()) >= 32
        )
        oidc_scheduler = bool(result.cron_oidc_audience and result.cron_service_account)
        if not strong_cron_secret and not oidc_scheduler:
            raise RuntimeError(
                "Configure a strong CRON_SECRET or Cloud Scheduler OIDC in production"
            )
        if "localhost" in result.mongo_uri or "127.0.0.1" in result.mongo_uri:
            raise RuntimeError(
                "MONGODB_URI must point to a remote cluster in production"
            )
        if not result.mongo_transactions:
            raise RuntimeError("MONGODB_TRANSACTIONS must be enabled in production")
        if not result.public_app_url.startswith("https://"):
            raise RuntimeError("PUBLIC_APP_URL must use HTTPS in production")
        if not result.smtp_host or not result.smtp_from or not result.smtp_password:
            raise RuntimeError("SMTP must be configured in production")
        if result.expose_dev_tokens:
            raise RuntimeError("EXPOSE_DEV_TOKENS cannot be enabled in production")
    return result
