from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.alert import AlertOut
from app.schemas.prediction import PredictionOut


class ReadingCreate(BaseModel):
    id_user: int = Field(ge=1)
    spo2_value: int | None = Field(default=None, ge=0, le=100)
    rr_value: int | None = Field(default=None, ge=0, le=80)
    hr_value: int | None = Field(default=None, ge=0, le=250)


class ReadingOut(BaseModel):
    id_physio: int
    id_user: int
    spo2_value: int | None = None
    rr_value: int | None = None
    hr_value: int | None = None
    time_of_record: datetime | None = None

    model_config = {"from_attributes": True}


class ReadingProcessOut(BaseModel):
    reading: ReadingOut
    prediction: PredictionOut
    alerts: list[AlertOut] = []

    model_config = {"from_attributes": True}
