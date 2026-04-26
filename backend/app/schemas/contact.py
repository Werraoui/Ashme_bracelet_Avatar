from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.db.models import RelationEnum


class ContactCreate(BaseModel):
    id_user: int = Field(ge=1)
    name_contact: str = Field(min_length=1)
    phone_contact: str = Field(min_length=1)
    email_contact: EmailStr | None = None
    relation: RelationEnum

    @field_validator("relation", mode="before")
    @classmethod
    def normalize_relation(cls, v):
        if isinstance(v, str):
            v = v.replace("_", " ").strip()
        return v


class ContactUpdate(BaseModel):
    name_contact: str | None = Field(default=None, min_length=1)
    phone_contact: str | None = Field(default=None, min_length=1)
    email_contact: EmailStr | None = None
    relation: RelationEnum | None = None

    @field_validator("relation", mode="before")
    @classmethod
    def normalize_relation(cls, v):
        if v is None:
            return v
        if isinstance(v, str):
            v = v.replace("_", " ").strip()
        return v


class ContactOut(BaseModel):
    id_contact: int
    id_user: int
    name_contact: str
    phone_contact: str
    email_contact: EmailStr | None = None
    relation: RelationEnum
    time_of_creation: datetime | None = None

    model_config = {"from_attributes": True}

