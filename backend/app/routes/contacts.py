from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import Contact, User
from app.schemas.contact import ContactCreate, ContactOut, ContactUpdate

contacts_route = APIRouter(prefix="/contacts", tags=["contacts"])


@contacts_route.post("", response_model=ContactOut, status_code=status.HTTP_201_CREATED)
def add_contact(payload: ContactCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id_user == payload.id_user).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Ensure enums are serialized to their DB values (e.g. "very close")
    contact = Contact(**payload.model_dump(mode="json"))
    db.add(contact)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Invalid contact data")

    db.refresh(contact)
    return contact


@contacts_route.get("/{id_user}", response_model=list[ContactOut])
def get_contacts_for_user(id_user: int, db: Session = Depends(get_db)):
    return db.query(Contact).filter(Contact.id_user == id_user).all()


@contacts_route.put("/{id_contact}", response_model=ContactOut)
def update_contact(id_contact: int, payload: ContactUpdate, db: Session = Depends(get_db)):
    contact = db.query(Contact).filter(Contact.id_contact == id_contact).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")

    data = payload.model_dump(exclude_unset=True, mode="json")
    for k, v in data.items():
        setattr(contact, k, v)

    db.commit()
    db.refresh(contact)
    return contact


@contacts_route.delete("/{id_contact}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(id_contact: int, db: Session = Depends(get_db)):
    contact = db.query(Contact).filter(Contact.id_contact == id_contact).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")

    db.delete(contact)
    db.commit()
    return None

