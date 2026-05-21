from __future__ import annotations

import os
from uuid import uuid4

from app.services.email_service import EmailSendError, send_email


class NotificationSendError(RuntimeError):
    pass


def send_alert_notification(
    *,
    to_email: str | None,
    to_phone: str | None,
    subject: str,
    message: str,
) -> tuple[str, str]:
    """
    Notify contact when an alert is raised.

    Priority:
    1) Email if `to_email` is set (recommended for university / free tier).
    2) Else SMS via Twilio if env vars are set and NOTIF_DRY_RUN is false.

    Returns (provider, provider_message_id_or_placeholder).

    Env:
    - NOTIF_DRY_RUN=true -> no real send; returns mock id
    """

    dry_run = (os.getenv("NOTIF_DRY_RUN") or os.getenv("SMS_DRY_RUN") or "false").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    if dry_run:
        raise NotificationSendError(
            "NOTIF_DRY_RUN est activé sur le serveur : aucun email réel n'est envoyé. "
            "Mettez NOTIF_DRY_RUN=false sur Render et configurez SMTP_*."
        )

    if to_email:
        try:
            send_email(to_email=to_email, subject=subject, text=message)
            return "email", "sent"
        except EmailSendError as e:
            raise NotificationSendError(str(e)) from e

    # Fallback: SMS (Twilio)
    if not to_phone:
        raise NotificationSendError("No email_contact and no phone_contact for notification")

    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    from_phone = os.getenv("TWILIO_FROM_PHONE")

    if not account_sid or not auth_token or not from_phone:
        raise NotificationSendError("No SMTP email and Twilio is not configured")

    try:
        from twilio.rest import Client

        client = Client(account_sid, auth_token)
        msg = client.messages.create(body=f"{subject}\n\n{message}", from_=from_phone, to=to_phone)
        return "twilio", msg.sid
    except Exception as e:
        raise NotificationSendError(str(e)) from e
