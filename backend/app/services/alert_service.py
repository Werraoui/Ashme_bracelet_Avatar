from __future__ import annotations

from datetime import datetime, timezone
import os
import secrets
from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models import Alerte, Contact, PredicResult, RelationEnum
from app.services.notification_service import NotificationSendError, send_alert_notification


RELATION_BY_STAGE: dict[int, RelationEnum] = {
    1: RelationEnum.very_close,
    2: RelationEnum.close,
    3: RelationEnum.not_that_close,
}


def escalate_stage(
    db: Session,
    *,
    prediction: PredicResult,
    escalation_group_id: UUID,
    stage: int,
    notify: bool,
) -> list[Alerte]:
    """
    Create alerts for a given stage (1/2/3) and optionally send notifications (email/SMS).

    We avoid duplicates: if an alert already exists for (id_predict, id_contact, stage),
    we skip creating it again.
    """

    target_relation = RELATION_BY_STAGE.get(stage, RelationEnum.very_close)
    contacts = (
        db.query(Contact)
        .filter(Contact.id_user == prediction.id_user, Contact.relation == target_relation)
        .all()
    )

    created: list[Alerte] = []

    for contact in contacts:
        existing = (
            db.query(Alerte)
            .filter(
                Alerte.id_predict == prediction.id_predict,
                Alerte.id_contact == contact.id_contact,
                Alerte.stage == stage,
            )
            .first()
        )
        if existing:
            continue

        alert = Alerte(
            id_user=prediction.id_user,
            id_predict=prediction.id_predict,
            id_contact=contact.id_contact,
            escalation_group_id=escalation_group_id,
            stage=stage,
            status="created",
        )
        db.add(alert)
        created.append(alert)

    if not created:
        return []

    db.commit()
    for a in created:
        db.refresh(a)

    if notify:
        for a in created:
            contact = next((c for c in contacts if c.id_contact == a.id_contact), None)
            if not contact:
                continue

            if not a.ack_token:
                a.ack_token = secrets.token_urlsafe(24)

            if not contact.email_contact and not contact.phone_contact:
                a.status = "failed"
                a.failed_at = datetime.now(timezone.utc)
                a.error_message = "Contact sans email ni téléphone — impossible d'envoyer l'alerte"
                continue

            status_fr = {
                "critical": "CRITIQUE",
                "warning": "ATTENTION",
                "normal": "NORMAL",
            }.get(prediction.status_predict.value, prediction.status_predict.value.upper())

            subject = f"🚨 AVATAR — Alerte asthme {status_fr}"
            message = (
                f"Alerte AVATAR ({status_fr})\n\n"
                f"Le patient (compte #{prediction.id_user}) présente des signes nécessitant votre attention.\n"
                f"Merci de prendre contact rapidement.\n"
            )
            try:
                base = os.getenv("PUBLIC_BASE_URL")
                if base:
                    ack_link = f"{base.rstrip('/')}/alerts/ack-link/{a.ack_token}"
                    message = message + f"\nAccuser réception / arrêter l'escalade :\n{ack_link}\n"
                elif contact.email_contact:
                    a.error_message = (
                        (a.error_message or "")
                        + " PUBLIC_BASE_URL non configuré sur le serveur (lien d'accusé absent)."
                    ).strip()

                provider, provider_message_id = send_alert_notification(
                    to_email=contact.email_contact,
                    to_phone=contact.phone_contact,
                    subject=subject,
                    message=message,
                )
                a.provider = provider
                a.provider_message_id = provider_message_id
                a.status = "sent"
                a.sent_at = datetime.now(timezone.utc)
                a.error_message = None
            except NotificationSendError as e:
                a.status = "failed"
                a.failed_at = datetime.now(timezone.utc)
                a.error_message = str(e)

        db.commit()
        for a in created:
            db.refresh(a)

    return created


def acknowledge_alert(db: Session, *, alert: Alerte, who: str) -> Alerte:
    """
    Acknowledge the alert and stop escalation for the whole group (same prediction + group_id).
    """

    ts = datetime.now(timezone.utc)
    (
        db.query(Alerte)
        .filter(
            Alerte.id_predict == alert.id_predict,
            Alerte.escalation_group_id == alert.escalation_group_id,
        )
        .update(
            {
                Alerte.status: "acknowledged",
                Alerte.acknowledged_at: ts,
                Alerte.acknowledged_by: who,
            },
            synchronize_session=False,
        )
    )
    db.commit()
    db.refresh(alert)
    return alert


def acknowledge_by_token(db: Session, *, token: str, who: str) -> Alerte:
    alert = db.query(Alerte).filter(Alerte.ack_token == token).first()
    if not alert:
        raise ValueError("Invalid token")
    return acknowledge_alert(db, alert=alert, who=who)

