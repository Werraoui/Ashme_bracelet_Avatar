from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import PhysioVariable
from app.schemas.readings import ReadingCreate, ReadingOut

readings_route = APIRouter(prefix="/readings", tags=["readings"])


@readings_route.post("", response_model=ReadingOut, status_code=status.HTTP_201_CREATED)
def add_reading(payload: ReadingCreate, db: Session = Depends(get_db)):
    reading = PhysioVariable(**payload.model_dump())
    db.add(reading)
    db.commit()
    db.refresh(reading)
    return reading


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

