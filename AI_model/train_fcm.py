import argparse
import re
from typing import Dict, List

import joblib
import numpy as np
import pandas as pd
import skfuzzy as fuzz
from sklearn.preprocessing import StandardScaler


DEFAULT_CSV_PATH = "data_avatar.csv"
DEFAULT_MODEL_PATH = "fcm_model.joblib"

# Noms canoniques attendus par le modele
CANONICAL_FEATURES = ["heart_rate", "respiratory_rate", "spo2"]

# Synonymes possibles de colonnes dans le CSV
SYNONYMS = {
    "heart_rate": [
        "heart_rate",
        "heart rate",
        "hr",
        "pulse",
        "frequence cardiaque",
    ],
    "respiratory_rate": [
        "respiratory_rate",
        "respiratory rate",
        "resp",
        "rr",
        "frequence respiratoire",
    ],
    "spo2": [
        "spo2",
        "oxygen saturation",
        "saturation oxygene",
        "oxygensaturation",
    ],
}


def _normalize_name(name: str) -> str:
    """Normalise un nom de colonne pour comparaison robuste."""
    name = name.strip().lower()
    name = re.sub(r"[\[\]\(\)%]", "", name)
    name = re.sub(r"[_\-\/]+", " ", name)
    name = re.sub(r"\s+", " ", name)
    return name


def detect_feature_columns(df: pd.DataFrame) -> Dict[str, str]:
    """
    Detecte les colonnes utiles automatiquement.
    Retourne un mapping: nom_canonique -> nom_reel_csv
    """
    normalized_to_original = {_normalize_name(col): col for col in df.columns}
    detected: Dict[str, str] = {}

    for canonical, candidates in SYNONYMS.items():
        found = None
        for candidate in candidates:
            norm_candidate = _normalize_name(candidate)
            if norm_candidate in normalized_to_original:
                found = normalized_to_original[norm_candidate]
                break
        if found is None:
            for normalized_col, original_col in normalized_to_original.items():
                if any(_normalize_name(candidate) in normalized_col for candidate in candidates):
                    found = original_col
                    break
        if found is None:
            raise ValueError(
                f"Colonne introuvable pour '{canonical}'. "
                f"Synonymes testes: {candidates}"
            )
        detected[canonical] = found

    return detected


def map_clusters_to_labels(
    centers_raw: np.ndarray, feature_order: List[str]
) -> Dict[int, str]:
    """
    Mappe automatiquement les clusters vers NORMAL/WARNING/CRITIQUE.
    On calcule un score de severite base sur:
    - HR eleve (plus risqué)
    - Respiratory rate eleve (plus risqué)
    - SpO2 faible (plus risqué)
    """
    idx_hr = feature_order.index("heart_rate")
    idx_resp = feature_order.index("respiratory_rate")
    idx_spo2 = feature_order.index("spo2")

    hr = centers_raw[:, idx_hr]
    resp = centers_raw[:, idx_resp]
    spo2 = centers_raw[:, idx_spo2]

    severity = hr + resp - spo2
    ordered = np.argsort(severity)  # petit = NORMAL, grand = CRITIQUE

    mapping = {
        int(ordered[0]): "NORMAL",
        int(ordered[1]): "WARNING",
        int(ordered[2]): "CRITIQUE",
    }
    return mapping


def train_fcm(csv_path: str = DEFAULT_CSV_PATH, model_path: str = DEFAULT_MODEL_PATH) -> None:
    """Entraine un modele FCM a 3 clusters puis sauvegarde les artefacts."""
    print(f"[INFO] Lecture du dataset: {csv_path}")
    df = pd.read_csv(csv_path)

    print("[INFO] Colonnes detectees dans le CSV:")
    print(list(df.columns))

    column_map = detect_feature_columns(df)
    print("[INFO] Mapping des colonnes utilisees:")
    print(column_map)

    work_df = df[[column_map[feature] for feature in CANONICAL_FEATURES]].copy()
    work_df.columns = CANONICAL_FEATURES

    work_df = work_df.apply(pd.to_numeric, errors="coerce")
    before_drop = len(work_df)
    work_df = work_df.dropna()
    after_drop = len(work_df)
    print(f"[INFO] Lignes supprimees (NaN/inconvertibles): {before_drop - after_drop}")

    if len(work_df) < 10:
        raise ValueError(
            "Pas assez de donnees apres nettoyage pour entrainer le modele "
            f"(lignes restantes: {len(work_df)})."
        )

    scaler = StandardScaler()
    x_scaled = scaler.fit_transform(work_df.values)

    n_clusters = 3
    m = 2.0
    error = 0.005
    maxiter = 1000
    seed = 42

    cntr, u, _, _, _, _, _ = fuzz.cluster.cmeans(
        data=x_scaled.T,
        c=n_clusters,
        m=m,
        error=error,
        maxiter=maxiter,
        seed=seed,
    )

    centers_raw = scaler.inverse_transform(cntr)
    cluster_label_map = map_clusters_to_labels(centers_raw, CANONICAL_FEATURES)

    artifact = {
        "scaler": scaler,
        "cluster_centers_scaled": cntr,
        "cluster_centers_raw": centers_raw,
        "feature_order": CANONICAL_FEATURES,
        "cluster_label_map": cluster_label_map,
        "label_risk_value_map": {"NORMAL": 0.0, "WARNING": 0.5, "CRITIQUE": 1.0},
        "fcm_params": {
            "n_clusters": n_clusters,
            "m": m,
            "error": error,
            "maxiter": maxiter,
            "seed": seed,
        },
    }
    joblib.dump(artifact, model_path)

    print(f"[OK] Modele sauvegarde: {model_path}")
    print("[INFO] Mapping cluster -> label:")
    print(cluster_label_map)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Entrainement Fuzzy C-Means (3 niveaux de risque)")
    parser.add_argument("--csv", default=DEFAULT_CSV_PATH, help="Chemin vers le fichier CSV")
    parser.add_argument("--out", default=DEFAULT_MODEL_PATH, help="Chemin du modele .joblib")
    args = parser.parse_args()

    train_fcm(csv_path=args.csv, model_path=args.out)
