from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import Alerte
from app.schemas.alert import AlertOut

alerts_route = APIRouter(prefix="/alerts", tags=["alerts"])


@alerts_route.get("/{id_user}", response_model=list[AlertOut])
def get_alerts_for_user(id_user: int, db: Session = Depends(get_db)):
    return db.query(Alerte).filter(Alerte.id_user == id_user).all()

