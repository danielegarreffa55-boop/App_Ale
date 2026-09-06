from __future__ import annotations

from email.message import EmailMessage
import logging
import smtplib
from urllib.parse import quote

from .config import settings

logger = logging.getLogger(__name__)


def _send(recipient: str, subject: str, body: str) -> bool:
    config = settings()
    if not config.smtp_host or not config.smtp_from:
        logger.warning("SMTP not configured; email '%s' was not sent", subject)
        return False
    try:
        message = EmailMessage()
        message["From"] = config.smtp_from
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(body)
        with smtplib.SMTP(config.smtp_host, config.smtp_port, timeout=15) as client:
            if config.smtp_use_tls:
                client.starttls()
            if config.smtp_username:
                client.login(config.smtp_username, config.smtp_password)
            client.send_message(message)
        return True
    except Exception:
        logger.exception("SMTP delivery failed for '%s'", subject)
        return False


def send_verification(recipient: str, token: str) -> bool:
    url = f"{settings().public_app_url.rstrip('/')}/#/verify-email?token={quote(token)}"
    return _send(
        recipient,
        "Verifica il tuo account Alessio Garreffa Hair",
        f"Apri questo link entro 24 ore per verificare il tuo account:\n\n{url}\n",
    )


def send_password_reset(recipient: str, token: str) -> bool:
    url = (
        f"{settings().public_app_url.rstrip('/')}/#/reset-password?token={quote(token)}"
    )
    return _send(
        recipient,
        "Reimposta la password Alessio Garreffa Hair",
        f"Apri questo link entro 30 minuti per scegliere una nuova password:\n\n{url}\n",
    )
