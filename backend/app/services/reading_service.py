from __future__ import annotations

from dataclasses import dataclass
from datetime import timezone
from uuid import uuid4
from sqlalchemy.orm import Session

from app.db.models import (
    Alerte,
    PhysioVariable,
    PredicResult,
    StatusPredictEnum,
)
from app.schemas.readings import ReadingCreate
from app.services.alert_service import escalate_stage


@dataclass(frozen=True)
class ReadingProcessResult:
    """
    Returned by process_reading() so the route can stay thin.
    - reading: saved PhysioVariable row
    - prediction: saved PredicResult row
    - alerts: any Alerte rows created by this processing step
    """

    reading: PhysioVariable
    prediction: PredicResult
    alerts: list[Alerte]


def classify_risk(spo2: int | None, rr: int | None, hr: int | None) -> StatusPredictEnum:
    """
    Simple rule-based classifier (no ML yet).

    Rules (requested):
    - spo2 < 92 OR hr > 120 OR rr > 30 -> critical
    - spo2 < 95 OR rr > 22             -> warning
    - otherwise              -> normal
    """

    if (
        (spo2 is not None and spo2 < 92)
        or (hr is not None and hr > 120)
        or (rr is not None and rr > 30)
    ):
        return StatusPredictEnum.critical

    if (spo2 is not None and spo2 < 95) or (rr is not None and rr > 22):
        return StatusPredictEnum.warning

    return StatusPredictEnum.normal


def process_reading(db: Session, payload: ReadingCreate) -> ReadingProcessResult:
    """
    Full processing pipeline for a new reading.

    Steps (requested):
    1) Save PhysioVariable
    2) Classify risk
    3) Save PredicResult
    4) Return early if normal
    5) If warning/critical: escalate alerts to contacts (stage-based)
    """

    # --- Step 1: Save reading ---
    reading = PhysioVariable(**payload.model_dump())
    db.add(reading)
    db.commit()
    db.refresh(reading)  # ensures reading.id_physio is available

    # --- Step 2: Classify risk ---
    status = classify_risk(
        spo2=reading.spo2_value,
        rr=reading.rr_value,
        hr=reading.hr_value,
    )

    # --- Step 3: Save prediction ---
    prediction = PredicResult(
        id_user=reading.id_user,
        id_physio=reading.id_physio,
        status_predict=status,
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)  # ensures prediction.id_predict is available

    # --- Step 4: Return early if normal ---
    if status == StatusPredictEnum.normal:
        return ReadingProcessResult(reading=reading, prediction=prediction, alerts=[])

    # --- Step 5: Escalation logic (stage-based) ---
    # For now we simulate ONLY the first stage: very_close contacts.
    escalation_group_id = uuid4()
    # Email notifications are sent only for CRITICAL readings (requested).
    notify = status == StatusPredictEnum.critical
    alerts_created = escalate_stage(
        db,
        prediction=prediction,
        escalation_group_id=escalation_group_id,
        stage=1,
        notify=notify,
    )
    return ReadingProcessResult(reading=reading, prediction=prediction, alerts=alerts_created)

