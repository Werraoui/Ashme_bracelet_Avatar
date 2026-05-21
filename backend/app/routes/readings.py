from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import PhysioVariable
from app.schemas.readings import ReadingCreate, ReadingOut, ReadingProcessOut
from app.services.reading_service import process_reading
from app.services.auth_dependencies import get_current_user
from app.db.models import User

readings_route = APIRouter(prefix="/readings", tags=["readings"])


@readings_route.post("", response_model=ReadingProcessOut, status_code=status.HTTP_201_CREATED)
def add_reading(
    payload: ReadingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id_user != payload.id_user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    result = process_reading(db, payload)
    return ReadingProcessOut(reading=result.reading, prediction=result.prediction)


@readings_route.get("/latest/{id_user}", response_model=ReadingOut)
def get_latest_reading(id_user: int, db: Session = Depends(get_db)):
    reading = (
        db.query(PhysioVariable)
        .filter(PhysioVariable.id_user == id_user)
        .order_by(PhysioVariable.time_of_record.desc())
        .first()
    )
    if not reading:
        raise HTTPException(status_code=404, detail="No readings found")
    return reading


@readings_route.get("/history/{id_user}", response_model=list[ReadingOut])
def get_readings_history(id_user: int, db: Session = Depends(get_db)):
    return (
        db.query(PhysioVariable)
        .filter(PhysioVariable.id_user == id_user)
        .order_by(PhysioVariable.time_of_record.desc())
        .all()
    )

