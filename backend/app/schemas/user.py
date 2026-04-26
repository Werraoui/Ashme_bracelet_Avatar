from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.db.models import GenderEnum


class UserCreate(BaseModel):
    last_name: str = Field(min_length=1)
    first_name: str = Field(min_length=1)
    email: EmailStr
    phone: str = Field(min_length=1)
    age: int = Field(ge=0, le=130)
    gender: GenderEnum
    pass_word: str = Field(min_length=6)


class UserUpdate(BaseModel):
    last_name: str | None = Field(default=None, min_length=1)
    first_name: str | None = Field(default=None, min_length=1)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=1)
    age: int | None = Field(default=None, ge=0, le=130)
    gender: GenderEnum | None = None


class AuthSignin(BaseModel):
    email: EmailStr
    pass_word: str = Field(min_length=1)


class AuthTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class UserOut(BaseModel):
    id_user: int
    last_name: str
    first_name: str
    email: EmailStr
    phone: str
    age: int
    gender: GenderEnum
    creation_date: datetime | None = None

    model_config = {"from_attributes": True}


AuthTokenOut.model_rebuild()

