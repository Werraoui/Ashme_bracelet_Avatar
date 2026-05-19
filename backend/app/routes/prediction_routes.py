from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services.prediction_service import predict_risk

router = APIRouter(prefix="/prediction", tags=["Prediction IA"])


class PredictionInput(BaseModel):
    heart_rate: float = Field(..., ge=0)
    respiratory_rate: float = Field(..., ge=0)
    spo2: float = Field(..., ge=0, le=100)


@router.post("/predict")
def predict(data: PredictionInput):
    try:
        return predict_risk(data.heart_rate, data.respiratory_rate, data.spo2)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
