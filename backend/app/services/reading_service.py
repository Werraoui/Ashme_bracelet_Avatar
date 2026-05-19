from __future__ import annotations

import logging
from dataclasses import dataclass
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
from app.services.prediction_service import classify_reading_status

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ReadingProcessResult:
    reading: PhysioVariable
    prediction: PredicResult
    alerts: list[Alerte]


def process_reading(db: Session, payload: ReadingCreate) -> ReadingProcessResult:
    """
    Full processing pipeline for a new reading:
    1) Insert physio_variables
    2) Classify risk (FCM model, rules fallback)
    3) Insert predic_results
    4) Escalate alerts when warning/critical
    """
    reading = PhysioVariable(**payload.model_dump())
    db.add(reading)
    db.commit()
    db.refresh(reading)
    logger.info(
        "Saved physio_variables id_physio=%s id_user=%s",
        reading.id_physio,
        reading.id_user,
    )

    status = classify_reading_status(
        spo2=reading.spo2_value,
        rr=reading.rr_value,
        hr=reading.hr_value,
    )

    prediction = PredicResult(
        id_user=reading.id_user,
        id_physio=reading.id_physio,
        status_predict=status,
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)
    logger.info(
        "Saved predic_results id_predict=%s status=%s",
        prediction.id_predict,
        status.value,
    )

    if status == StatusPredictEnum.normal:
        return ReadingProcessResult(reading=reading, prediction=prediction, alerts=[])

    escalation_group_id = uuid4()
    notify = status == StatusPredictEnum.critical
    alerts_created = escalate_stage(
        db,
        prediction=prediction,
        escalation_group_id=escalation_group_id,
        stage=1,
        notify=notify,
    )
    return ReadingProcessResult(reading=reading, prediction=prediction, alerts=alerts_created)
