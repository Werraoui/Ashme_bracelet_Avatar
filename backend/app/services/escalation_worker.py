from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from sqlalchemy import func

from app.db.database import SessionLocal
from app.db.models import Alerte, PredicResult, StatusPredictEnum
from app.services.alert_service import escalate_stage


POLL_SECONDS = 5
STAGE_TIMEOUT_SECONDS = 30


async def run_escalation_loop() -> None:
    """
    Background loop:
    - Finds CRITICAL predictions with alerts not acknowledged
    - If the current stage has been pending >= 30s, escalates to the next stage

    Notes:
    - This is a simple in-process worker (good for dev/university).
    - In production you'd move this to a real job queue / scheduler.
    """

    while True:
        try:
            _tick()
        except Exception:
            # Keep the loop alive even if one tick fails.
            pass

        await asyncio.sleep(POLL_SECONDS)


def _tick() -> None:
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=STAGE_TIMEOUT_SECONDS)

    db = SessionLocal()
    try:
        # Consider only CRITICAL predictions (your email logic is critical-only).
        # For each prediction, find max(stage) and the oldest "sent_at/time_of_alert" for that stage.
        rows = (
            db.query(
                Alerte.id_predict.label("id_predict"),
                Alerte.escalation_group_id.label("group_id"),
                func.max(Alerte.stage).label("current_stage"),
            )
            .join(PredicResult, PredicResult.id_predict == Alerte.id_predict)
            .filter(PredicResult.status_predict == StatusPredictEnum.critical)
            .group_by(Alerte.id_predict, Alerte.escalation_group_id)
            .all()
        )

        for r in rows:
            id_predict = int(r.id_predict)
            group_id = r.group_id
            current_stage = int(r.current_stage or 1)

            # Stop if already acknowledged (any alert in group acknowledged).
            ack_exists = (
                db.query(Alerte.id_alerte)
                .filter(
                    Alerte.id_predict == id_predict,
                    Alerte.escalation_group_id == group_id,
                    Alerte.acknowledged_at.isnot(None),
                )
                .first()
            )
            if ack_exists:
                continue

            if current_stage >= 3:
                continue

            # Get stage "start time": prefer sent_at, otherwise time_of_alert.
            stage_time = (
                db.query(func.min(func.coalesce(Alerte.sent_at, Alerte.time_of_alert)))
                .filter(
                    Alerte.id_predict == id_predict,
                    Alerte.escalation_group_id == group_id,
                    Alerte.stage == current_stage,
                )
                .scalar()
            )
            if not stage_time:
                continue

            # If stage has been running longer than 30s, escalate to next stage.
            if stage_time <= cutoff:
                prediction = (
                    db.query(PredicResult).filter(PredicResult.id_predict == id_predict).first()
                )
                if not prediction:
                    continue

                next_stage = current_stage + 1
                escalate_stage(
                    db,
                    prediction=prediction,
                    escalation_group_id=group_id,
                    stage=next_stage,
                    notify=True,
                )
    finally:
        db.close()

