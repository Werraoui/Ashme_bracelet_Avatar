# Projet PFE - Prediction risque asthme nocturne (Fuzzy C-Means)

Ce projet contient:
- un script d'entrainement `train_fcm.py`
- des utilitaires modele `model_utils.py`
- une API FastAPI `main.py`

Le modele utilise **FCM = Fuzzy C-Means** (pas Firebase Cloud Messaging).

## 1) Installation

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## 2) Entrainement du modele

```bash
python train_fcm.py --csv data_avatar.csv --out fcm_model.joblib
```

Le script:
- lit le CSV avec `pandas`
- affiche les colonnes trouvees
- detecte automatiquement les colonnes utiles (HR, respiration, SpO2)
- nettoie les donnees (conversion numerique + suppression des NaN)
- normalise avec `StandardScaler`
- entraine Fuzzy C-Means en 3 clusters
- mappe automatiquement les clusters vers `NORMAL`, `WARNING`, `CRITIQUE`
- sauvegarde le modele avec `joblib`

### Important si erreur de colonne manquante

Si une colonne est absente (`heart_rate`, `respiratory_rate` ou `spo2`), le script leve une erreur claire.

## 3) Lancer l'API FastAPI

```bash
uvicorn main:app --reload
```

API disponible sur:
- docs Swagger: `http://127.0.0.1:8000/docs`
- health check: `http://127.0.0.1:8000/health`

## 4) Tester `/predict`

Exemple de requete:

```bash
curl -X POST "http://127.0.0.1:8000/predict" ^
  -H "Content-Type: application/json" ^
  -d "{\"heart_rate\":110,\"respiratory_rate\":24,\"spo2\":92}"
```

Exemple de reponse:

```json
{
  "risk_score": 0.75,
  "risk_label": "WARNING",
  "memberships": {
    "NORMAL": 0.1,
    "WARNING": 0.75,
    "CRITIQUE": 0.15
  }
}
```

## 5) Connexion avec Supabase (apres prediction)

Principe simple:
1. Votre front/mobile envoie les capteurs a `POST /predict`.
2. L'API retourne `risk_score`, `risk_label`, `memberships`.
3. Votre backend (ou un autre service) enregistre ce resultat dans Supabase.

### Exemple de table Supabase

Table `predictions`:
- `id` (uuid, pk)
- `patient_id` (text ou uuid)
- `heart_rate` (float)
- `respiratory_rate` (float)
- `spo2` (float)
- `risk_score` (float)
- `risk_label` (text)
- `memberships` (jsonb)
- `created_at` (timestamp)

### Exemple Python (idee)

```python
from supabase import create_client

url = "https://YOUR_PROJECT.supabase.co"
key = "YOUR_SUPABASE_SERVICE_ROLE_KEY"
supabase = create_client(url, key)

payload = {
    "patient_id": "P001",
    "heart_rate": 110,
    "respiratory_rate": 24,
    "spo2": 92,
    "risk_score": 0.75,
    "risk_label": "WARNING",
    "memberships": {"NORMAL": 0.1, "WARNING": 0.75, "CRITIQUE": 0.15},
}

supabase.table("predictions").insert(payload).execute()
```

Conseil: utilisez la **service role key uniquement cote serveur** (jamais dans le frontend).
