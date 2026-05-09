from __future__ import annotations

import os
import smtplib
from email.message import EmailMessage


class EmailSendError(RuntimeError):
    pass


def send_email(*, to_email: str, subject: str, text: str) -> None:
    """
    Minimal SMTP sender for alert notifications.

    Required env vars:
    - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
    Optional:
    - SMTP_TLS=true|false (default true)
    """

    host = os.getenv("SMTP_HOST")
    port = int(os.getenv("SMTP_PORT") or "587")
    user = os.getenv("SMTP_USER")
    password = os.getenv("SMTP_PASS")
    from_email = os.getenv("SMTP_FROM")
    tls = (os.getenv("SMTP_TLS") or "true").lower() in {"1", "true", "yes", "on"}

    if not host or not user or not password or not from_email:
        raise EmailSendError("Missing SMTP environment variables")

    msg = EmailMessage()
    msg["From"] = from_email
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(text)

    try:
        with smtplib.SMTP(host, port, timeout=20) as server:
            if tls:
                server.starttls()
            server.login(user, password)
            server.send_message(msg)
    except Exception as e:
        raise EmailSendError(str(e)) from e
