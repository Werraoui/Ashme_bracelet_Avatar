from datetime import datetime

from uuid import UUID

from pydantic import BaseModel, Field


class AlertOut(BaseModel):
    id_alerte: int
    id_user: int = Field(ge=1)
    id_predict: int = Field(ge=1)
    id_contact: int = Field(ge=1)
    time_of_alert: datetime | None = None

    escalation_group_id: UUID
    stage: int
    status: str

    provider: str | None = None
    provider_message_id: str | None = None

    sent_at: datetime | None = None
    delivered_at: datetime | None = None
    failed_at: datetime | None = None
    acknowledged_at: datetime | None = None
    acknowledged_by: str | None = None
    error_message: str | None = None

    model_config = {"from_attributes": True}

