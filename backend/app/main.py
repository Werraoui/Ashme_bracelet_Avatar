from contextlib import asynccontextmanager
import asyncio
import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.services.escalation_worker import run_escalation_loop

from app.routes.alerts import alerts_route
from app.routes.auth import auth_route
from app.routes.contacts import contacts_route
from app.routes.readings import readings_route
from app.routes.users import users_route
from app.routes.prediction_routes import router as prediction_router
from app.routes.predictions import predictions_route

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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

# Required for Flutter Web (localhost) calling this API on Render.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(auth_route)
app.include_router(users_route)
app.include_router(contacts_route)
app.include_router(readings_route)
app.include_router(predictions_route)
app.include_router(alerts_route)
app.include_router(prediction_router)


@app.get("/", tags=["health"])
def health():
    return {"status": "ok"}
