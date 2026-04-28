import os
from typing import Dict, List

import joblib
import numpy as np
import skfuzzy as fuzz


MODEL_PATH = "fcm_model.joblib"


def load_model(model_path: str = MODEL_PATH) -> Dict:
    """Charge le modele FCM sauvegarde."""
    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"Modele introuvable: {model_path}. Lance d'abord train_fcm.py."
        )
    return joblib.load(model_path)


def _validate_input(input_data: Dict, feature_order: List[str]) -> np.ndarray:
    """Valide et convertit l'entree capteur en vecteur numpy."""
    missing = [feature for feature in feature_order if feature not in input_data]
    if missing:
        raise ValueError(f"Champs manquants dans input_data: {missing}")

    values = []
    for feature in feature_order:
        try:
            values.append(float(input_data[feature]))
        except (TypeError, ValueError) as exc:
            raise ValueError(f"Valeur invalide pour '{feature}': {input_data[feature]}") from exc

    return np.array(values, dtype=float).reshape(1, -1)


def predict_risk(input_data: Dict, model_artifact: Dict | None = None) -> Dict:
    """
    Retourne un score de risque avec Fuzzy C-Means (3 labels).
    - memberships: degres d'appartenance pour NORMAL/WARNING/CRITIQUE
    - risk_label: label dominant (max membership)
    - risk_score: score pondere selon:
        NORMAL=0.0, WARNING=0.5, CRITIQUE=1.0
    """
    if model_artifact is None:
        model_artifact = load_model()

    scaler = model_artifact["scaler"]
    centers = model_artifact["cluster_centers_scaled"]
    feature_order = model_artifact["feature_order"]
    cluster_label_map = model_artifact["cluster_label_map"]
    label_risk_value_map = model_artifact["label_risk_value_map"]
    m = float(model_artifact["fcm_params"]["m"])
    error = float(model_artifact["fcm_params"]["error"])
    maxiter = int(model_artifact["fcm_params"]["maxiter"])

    x = _validate_input(input_data, feature_order)
    x_scaled = scaler.transform(x)

    u_pred, _, _, _, _, _ = fuzz.cluster.cmeans_predict(
        test_data=x_scaled.T,
        cntr_trained=centers,
        m=m,
        error=error,
        maxiter=maxiter,
    )

    memberships: Dict[str, float] = {"NORMAL": 0.0, "WARNING": 0.0, "CRITIQUE": 0.0}
    for cluster_idx, label in cluster_label_map.items():
        memberships[label] = float(u_pred[int(cluster_idx)][0])

    risk_label = max(memberships, key=memberships.get)
    risk_score = sum(
        memberships[label] * float(label_risk_value_map[label]) for label in memberships
    )

    return {
        "risk_score": round(risk_score, 4),
        "risk_label": risk_label,
        "memberships": {k: round(v, 4) for k, v in memberships.items()},
    }
