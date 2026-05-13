from contextlib import asynccontextmanager
import asyncio

from fastapi import FastAPI

from app.services.escalation_worker import run_escalation_loop

from app.routes.alerts import alerts_route
from app.routes.auth import auth_route
from app.routes.contacts import contacts_route
from app.routes.readings import readings_route
from app.routes.users import users_route
from app.routes.prediction_routes import router as prediction_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(run_escalation_loop())
    try:
        yield
    finally:
        task.cancel()


app = FastAPI(
    title="Ashtme Monitoring API",
    version="0.1.0",
    description="FastAPI backend for asthma monitoring (Supabase Postgres).",
    lifespan=lifespan,
)

app.include_router(auth_route)
app.include_router(users_route)
app.include_router(contacts_route)
app.include_router(readings_route)
app.include_router(alerts_route)
app.include_router(prediction_router)


@app.get("/", tags=["health"])
def health():
    return {"status": "ok"}
