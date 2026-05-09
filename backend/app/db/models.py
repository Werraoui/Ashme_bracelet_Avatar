import enum
from sqlalchemy import Column, Integer, String, Text, Enum as SAEnum, ForeignKey, TIMESTAMP, SmallInteger
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base
import uuid


# ─────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────

class GenderEnum(str, enum.Enum):
    male = "male"
    female = "female"


class RelationEnum(str, enum.Enum):
    very_close = "very close" 
    close = "close" 
    not_that_close = "not that close"


class StatusPredictEnum(str, enum.Enum):
    normal = "normal"
    warning = "warning"
    critical = "critical"


# ─────────────────────────────────────────
# USERS
# ─────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id_user       = Column(Integer, primary_key=True, index=True)
    last_name     = Column(String, nullable=False)
    first_name    = Column(String, nullable=False)
    email         = Column(String, unique=True, nullable=False)
    phone         = Column(String, unique=True, nullable=False)
    age           = Column(Integer, nullable=False)
    gender        = Column(SAEnum(GenderEnum), nullable=False)
    pass_word     = Column(Text, nullable=False)
    creation_date = Column(TIMESTAMP, server_default=func.now())

    # Relationships
    contacts         = relationship("Contact", back_populates="user")
    physio_variables = relationship("PhysioVariable", back_populates="user")
    predic_results   = relationship("PredicResult", back_populates="user")
    alertes          = relationship("Alerte", back_populates="user")


# ─────────────────────────────────────────
# CONTACTS
# ─────────────────────────────────────────

class Contact(Base):
    __tablename__ = "contacts"

    id_contact      = Column(Integer, primary_key=True, index=True)
    id_user         = Column(Integer, ForeignKey("users.id_user"), nullable=False)
    name_contact    = Column(String, nullable=False)
    phone_contact   = Column(String, nullable=False)
    email_contact   = Column(String, nullable=True)
    # Use enum *values* (e.g. "very close") to match the existing Postgres enum labels.
    relation        = Column(
        SAEnum(
            RelationEnum,
            name="relation_enum",
            values_callable=lambda enum_cls: [e.value for e in enum_cls],
            create_type=False,
        ),
        nullable=False,
    )
    time_of_creation = Column(TIMESTAMP, server_default=func.now())

    # Relationships
    user    = relationship("User", back_populates="contacts")
    alertes = relationship("Alerte", back_populates="contact")


# ─────────────────────────────────────────
# PHYSIO VARIABLES
# ─────────────────────────────────────────

class PhysioVariable(Base):
    __tablename__ = "physio_variables"

    id_physio      = Column(Integer, primary_key=True, index=True)
    id_user        = Column(Integer, ForeignKey("users.id_user"), nullable=False)
    spo2_value     = Column(SmallInteger, nullable=True)   # oxygen saturation
    rr_value       = Column(SmallInteger, nullable=True)   # respiratory rate
    hr_value       = Column(SmallInteger, nullable=True)   # heart rate
    time_of_record = Column(TIMESTAMP, server_default=func.now())

    # Relationships
    user           = relationship("User", back_populates="physio_variables")
    predic_results = relationship("PredicResult", back_populates="physio_variable")


# ─────────────────────────────────────────
# PREDIC RESULTS
# ─────────────────────────────────────────

class PredicResult(Base):
    __tablename__ = "predic_results"

    id_predict       = Column(Integer, primary_key=True, index=True)
    id_user          = Column(Integer, ForeignKey("users.id_user"), nullable=False)
    id_physio        = Column(Integer, ForeignKey("physio_variables.id_physio"), nullable=False)
    status_predict   = Column(SAEnum(StatusPredictEnum), nullable=False)
    time_of_creation = Column(TIMESTAMP, server_default=func.now())

    # Relationships
    user            = relationship("User", back_populates="predic_results")
    physio_variable = relationship("PhysioVariable", back_populates="predic_results")
    alertes         = relationship("Alerte", back_populates="predic_result")


# ─────────────────────────────────────────
# ALERTES
# ─────────────────────────────────────────

class Alerte(Base):
    __tablename__ = "alertes"

    id_alerte     = Column(Integer, primary_key=True, index=True)
    id_user       = Column(Integer, ForeignKey("users.id_user"), nullable=False)
    id_predict    = Column(Integer, ForeignKey("predic_results.id_predict"), nullable=False)
    id_contact    = Column(Integer, ForeignKey("contacts.id_contact"), nullable=False)
    time_of_alert = Column(TIMESTAMP, server_default=func.now())

    # Escalation + notification tracking (added for step-based escalation + SMS)
    escalation_group_id = Column(UUID(as_uuid=True), default=uuid.uuid4, nullable=False)
    stage = Column(SmallInteger, nullable=False, default=1)
    status = Column(String, nullable=False, default="created")

    provider = Column(String, nullable=True)
    provider_message_id = Column(String, nullable=True)
    ack_token = Column(String, unique=True, nullable=True)

    sent_at = Column(TIMESTAMP, nullable=True)
    delivered_at = Column(TIMESTAMP, nullable=True)
    failed_at = Column(TIMESTAMP, nullable=True)
    acknowledged_at = Column(TIMESTAMP, nullable=True)
    acknowledged_by = Column(String, nullable=True)
    error_message = Column(Text, nullable=True)

    # Relationships
    user          = relationship("User", back_populates="alertes")
    predic_result = relationship("PredicResult", back_populates="alertes")
    contact       = relationship("Contact", back_populates="alertes")