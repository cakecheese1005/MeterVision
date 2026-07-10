from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.routers import auth, readings, sync
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"PSPCL Backend starting — env: {settings.ENVIRONMENT}")
    yield
    print("PSPCL Backend shutting down")


app = FastAPI(
    title="PSPCL Meter Reading API",
    version="1.0.0",
    description="Backend for PSPCL offline-first meter reading system",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,     prefix="/auth",     tags=["Auth"])
app.include_router(readings.router, prefix="/readings", tags=["Readings"])
app.include_router(sync.router,     prefix="/sync",     tags=["Sync"])


@app.get("/health")
def health():
    return {"status": "ok", "version": "1.0.0"}
