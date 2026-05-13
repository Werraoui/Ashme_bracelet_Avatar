from fastapi import APIRouter
from pydantic import BaseModel

from app.services.prediction_service import predict_risk

router = APIRouter(
    prefix="/prediction",
    tags=["Prediction IA"]
)

class PredictionInput(BaseModel):
    heart_rate: float
    respiratory_rate: float
    spo2: float

@router.post("/predict")
def predict(data: PredictionInput):
    return predict_risk(
        data.heart_rate,
        data.respiratory_rate,
        data.spo2
    )