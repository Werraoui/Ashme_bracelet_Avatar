from __future__ import annotations

import logging
from functools import lru_cache
from pathlib import Path

import joblib
import numpy as np
from scipy.spatial.distance import cdist

from app.db.models import StatusPredictEnum

logger = logging.getLogger(__name__)

_MODEL_PATH = Path(__file__).resolve().parents[2] / "AI_model" / "fcm_model.joblib"

_LABEL_TO_STATUS: dict[str, StatusPredictEnum] = {
    "NORMAL": StatusPredictEnum.normal,
    "WARNING": StatusPredictEnum.warning,
    "CRITIQUE": StatusPredictEnum.critical,
}


@lru_cache(maxsize=1)
def _load_model() -> dict:
    if not _MODEL_PATH.is_file():
        raise FileNotFoundError(f"FCM model not found at {_MODEL_PATH}")
    logger.info("Loading FCM model from %s", _MODEL_PATH)
    return joblib.load(_MODEL_PATH)


def ml_label_to_status(risk_label: str) -> StatusPredictEnum:
    key = (risk_label or "").strip().upper()
    return _LABEL_TO_STATUS.get(key, StatusPredictEnum.normal)


def predict_risk(
    heart_rate: float | int | None,
    respiratory_rate: float | int | None,
    spo2: float | int | None,
) -> dict:
    """
    Run FCM inference on HR, RR, SpO2.
    Returns risk_label (NORMAL/WARNING/CRITIQUE), risk_score, and memberships.
    """
    if heart_rate is None or respiratory_rate is None or spo2 is None:
        raise ValueError("heart_rate, respiratory_rate, and spo2 are required for ML prediction")

    model_data = _load_model()
    scaler = model_data["scaler"]
    centers = model_data["cluster_centers_scaled"]
    cluster_label_map = model_data["cluster_label_map"]
    label_risk_value_map = model_data["label_risk_value_map"]

    x = np.array([[float(heart_rate), float(respiratory_rate), float(spo2)]])
    x_scaled = scaler.transform(x)

    distances = cdist(x_scaled, centers)
    inv_distances = 1.0 / (distances + 1e-8)
    memberships = inv_distances / inv_distances.sum()

    max_index = int(np.argmax(memberships))
    risk_label = cluster_label_map[max_index]
    risk_score = label_risk_value_map[risk_label]

    return {
        "risk_score": float(risk_score),
        "risk_label": risk_label,
        "status_predict": ml_label_to_status(risk_label).value,
        "memberships": {
            cluster_label_map[i]: float(memberships[0][i])
            for i in range(len(memberships[0]))
        },
    }


def _max_severity(a: StatusPredictEnum, b: StatusPredictEnum) -> StatusPredictEnum:
    """Keep the most severe status (critical > warning > normal)."""
    order = {
        StatusPredictEnum.normal: 0,
        StatusPredictEnum.warning: 1,
        StatusPredictEnum.critical: 2,
    }
    return a if order[a] >= order[b] else b


def classify_reading_status(
    spo2: int | None,
    rr: int | None,
    hr: int | None,
) -> StatusPredictEnum:
    """
    FCM model + medical rule thresholds.
    Clinical rules can elevate ML output (e.g. SpO2 < 92 → critical even if FCM says warning).
    """
    rule_status = _classify_risk_rules(spo2=spo2, rr=rr, hr=hr)

    if spo2 is not None and rr is not None and hr is not None:
        try:
            result = predict_risk(hr, rr, spo2)
            ml_status = ml_label_to_status(result["risk_label"])
            return _max_severity(ml_status, rule_status)
        except Exception as exc:
            logger.warning("ML classification failed, using rules: %s", exc)

    return rule_status


def _classify_risk_rules(
    spo2: int | None,
    rr: int | None,
    hr: int | None,
) -> StatusPredictEnum:
    if (
        (spo2 is not None and spo2 < 92)
        or (hr is not None and hr > 120)
        or (rr is not None and rr > 30)
    ):
        return StatusPredictEnum.critical

    if (spo2 is not None and spo2 < 95) or (rr is not None and rr > 22):
        return StatusPredictEnum.warning

    return StatusPredictEnum.normal
