from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import User
from app.schemas.user import AuthSignin, AuthTokenOut, UserCreate, UserOut

auth_route = APIRouter(prefix="/auth", tags=["auth"])


@auth_route.post("/signup", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def signup(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == str(payload.email)).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")

    user = User(**payload.model_dump())
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@auth_route.post("/signin", response_model=AuthTokenOut)
def signin(payload: AuthSignin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == str(payload.email)).first()
    if not user or user.pass_word != payload.pass_word:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = f"mock-{uuid4()}"
    return {"access_token": token, "token_type": "bearer", "user": user}


@auth_route.post("/logout")
def logout():
    return {"message": "logged out"}

