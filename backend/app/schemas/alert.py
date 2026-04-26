from datetime import datetime

from pydantic import BaseModel, Field


class AlertOut(BaseModel):
    id_alerte: int
    id_user: int = Field(ge=1)
    id_predict: int = Field(ge=1)
    id_contact: int = Field(ge=1)
    time_of_alert: datetime | None = None

    model_config = {"from_attributes": True}

