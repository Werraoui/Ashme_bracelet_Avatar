from fastapi import FastAPI

from app.routes.alerts import alerts_route
from app.routes.auth import auth_route
from app.routes.contacts import contacts_route
from app.routes.readings import readings_route
from app.routes.users import users_route

app = FastAPI(
    title="Ashtme Monitoring API",
    version="0.1.0",
    description="FastAPI backend for asthma monitoring (Supabase Postgres).",
)

app.include_router(auth_route)
app.include_router(users_route)
app.include_router(contacts_route)
app.include_router(readings_route)
app.include_router(alerts_route)


@app.get("/", tags=["health"])
def health():
    return {"status": "ok"}
