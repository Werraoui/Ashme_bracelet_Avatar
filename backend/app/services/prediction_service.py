import joblib
import numpy as np
from scipy.spatial.distance import cdist

model_data = joblib.load("AI_model/fcm_model.joblib")

def predict_risk(heart_rate, respiratory_rate, spo2):
    scaler = model_data["scaler"]
    centers = model_data["cluster_centers_scaled"]
    cluster_label_map = model_data["cluster_label_map"]
    label_risk_value_map = model_data["label_risk_value_map"]

    X = np.array([[heart_rate, respiratory_rate, spo2]])
    X_scaled = scaler.transform(X)

    distances = cdist(X_scaled, centers)

    inv_distances = 1 / (distances + 1e-8)
    memberships = inv_distances / inv_distances.sum()

    max_index = int(np.argmax(memberships))

    risk_label = cluster_label_map[max_index]
    risk_score = label_risk_value_map[risk_label]

    return {
        "risk_score": risk_score,
        "risk_label": risk_label,
        "memberships": {
            cluster_label_map[i]: float(memberships[0][i])
            for i in range(len(memberships[0]))
        }
    }