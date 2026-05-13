from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from AI_model.model_utils import load_model, predict_risk


app = FastAPI(
    title="Asthma Night Risk API",
    description="API de prediction du risque de crise d'asthme nocturne via Fuzzy C-Means.",
    version="1.0.0",
)


class SensorInput(BaseModel):
    heart_rate: float = Field(..., example=110)
    respiratory_rate: float = Field(..., example=24)
    spo2: float = Field(..., example=92)


MODEL_ARTIFACT = None


@app.on_event("startup")
def startup_event() -> None:
    """Charge le modele au demarrage de l'API."""
    global MODEL_ARTIFACT
    try:
        MODEL_ARTIFACT = load_model()
    except FileNotFoundError:
        # L'API reste accessible, mais /predict renverra une erreur claire.
        MODEL_ARTIFACT = None


@app.get("/health")
def health() -> dict:
    """Route simple pour verifier que l'API tourne."""
    return {
        "status": "ok",
        "model_loaded": MODEL_ARTIFACT is not None,
    }


@app.post("/predict")
def predict(payload: SensorInput) -> dict:
    """Recoit les donnees capteurs et retourne la prediction de risque."""
    if MODEL_ARTIFACT is None:
        raise HTTPException(
            status_code=503,
            detail="Modele non charge. Lancez d'abord l'entrainement (train_fcm.py).",
        )

    try:
        return predict_risk(payload.model_dump(), MODEL_ARTIFACT)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Erreur interne: {exc}") from exc
