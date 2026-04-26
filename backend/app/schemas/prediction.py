from datetime import datetime

from pydantic import BaseModel

from app.db.models import StatusPredictEnum


class PredictionOut(BaseModel):
    id_predict: int
    id_user: int
    id_physio: int
    status_predict: StatusPredictEnum
    time_of_creation: datetime | None = None

    model_config = {"from_attributes": True}
