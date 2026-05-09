from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import User
from app.schemas.user import AuthSignin, AuthTokenOut, UserCreate, UserOut
from app.services.auth_service import create_access_token, hash_password, verify_password

auth_route = APIRouter(prefix="/auth", tags=["auth"])


@auth_route.post("/signup", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def signup(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == str(payload.email)).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")

    data = payload.model_dump()
    data["pass_word"] = hash_password(data["pass_word"])
    user = User(**data)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@auth_route.post("/signin", response_model=AuthTokenOut)
def signin(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # This endpoint is OAuth2PasswordBearer-compatible for Swagger "Authorize".
    # Swagger sends "username" and "password" as form fields.
    user = db.query(User).filter(User.email == str(form.username)).first()
    if not user or not verify_password(form.password, user.pass_word):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(subject=str(user.id_user))
    return {"access_token": token, "token_type": "bearer", "user": user}


@auth_route.post("/signin-json", response_model=AuthTokenOut)
def signin_json(payload: AuthSignin, db: Session = Depends(get_db)):
    # Backwards-compatible JSON login (email + pass_word).
    user = db.query(User).filter(User.email == str(payload.email)).first()
    if not user or not verify_password(payload.pass_word, user.pass_word):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(subject=str(user.id_user))
    return {"access_token": token, "token_type": "bearer", "user": user}


@auth_route.post("/logout")
def logout():
    return {"message": "logged out"}

