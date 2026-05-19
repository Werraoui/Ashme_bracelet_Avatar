from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import PredicResult
from app.schemas.prediction import PredictionOut

predictions_route = APIRouter(prefix="/predictions", tags=["predictions"])


@predictions_route.get("/latest/{id_user}", response_model=PredictionOut)
def get_latest_prediction(id_user: int, db: Session = Depends(get_db)):
    prediction = (
        db.query(PredicResult)
        .filter(PredicResult.id_user == id_user)
        .order_by(PredicResult.time_of_creation.desc())
        .first()
    )
    if not prediction:
        raise HTTPException(status_code=404, detail="No predictions found")
    return prediction


@predictions_route.get("/history/{id_user}", response_model=list[PredictionOut])
def get_predictions_history(id_user: int, db: Session = Depends(get_db)):
    return (
        db.query(PredicResult)
        .filter(PredicResult.id_user == id_user)
        .order_by(PredicResult.time_of_creation.desc())
        .all()
    )
