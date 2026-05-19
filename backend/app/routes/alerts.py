from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import PlainTextResponse
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import Alerte, PredicResult, User
from app.schemas.alert import AlertOut
from app.services.auth_dependencies import get_current_user
from app.services.alert_service import acknowledge_alert, acknowledge_by_token, escalate_stage

alerts_route = APIRouter(prefix="/alerts", tags=["alerts"])


@alerts_route.get("/ack-link/{token}", response_class=PlainTextResponse)
def ack_by_email_link(token: str, db: Session = Depends(get_db)):
    """Public endpoint for contacts: clicking the link acknowledges the alert group."""
    try:
        acknowledge_by_token(db, token=token, who="contact")
    except ValueError:
        raise HTTPException(status_code=404, detail="Invalid token")

    return "Acknowledged. Thank you."


@alerts_route.get("/{id_user}", response_model=list[AlertOut])
def get_alerts_for_user(
    id_user: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id_user != id_user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    rows = (
        db.query(Alerte, PredicResult.status_predict)
        .join(PredicResult, Alerte.id_predict == PredicResult.id_predict)
        .filter(Alerte.id_user == id_user)
        .order_by(Alerte.time_of_alert.desc())
        .all()
    )

    results: list[AlertOut] = []
    for alert, status_predict in rows:
        out = AlertOut.model_validate(alert)
        out.status_predict = status_predict.value if status_predict else None
        results.append(out)
    return results


@alerts_route.post("/{id_alerte}/ack", response_model=AlertOut)
def ack_alert(
    id_alerte: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    alert = db.query(Alerte).filter(Alerte.id_alerte == id_alerte).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    if alert.id_user != current_user.id_user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    alert = acknowledge_alert(db, alert=alert, who="user")
    return AlertOut.model_validate(alert)


@alerts_route.post("/escalate/{id_predict}", response_model=list[AlertOut])
def escalate_next_stage(
    id_predict: int,
    stage: int = 2,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    prediction = db.query(PredicResult).filter(PredicResult.id_predict == id_predict).first()
    if not prediction:
        raise HTTPException(status_code=404, detail="Prediction not found")
    if prediction.id_user != current_user.id_user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    first_alert = (
        db.query(Alerte)
        .filter(Alerte.id_predict == id_predict)
        .order_by(Alerte.time_of_alert.asc())
        .first()
    )
    escalation_group_id = (
        first_alert.escalation_group_id if first_alert else __import__("uuid").uuid4()
    )

    created = escalate_stage(
        db,
        prediction=prediction,
        escalation_group_id=escalation_group_id,
        stage=stage,
        notify=True,
    )
    return [AlertOut.model_validate(a) for a in created]
