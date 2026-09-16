from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings

from app.routers import (
    auth,
    users,
    consumer,
    readings,
    images,
    sync,
    dashboard,
    anomalies,
    lcr,
    notifications,
    ocr,
)


# =========================================================
# LIFESPAN
# =========================================================

@asynccontextmanager
async def lifespan(app: FastAPI):

    print(
        f"PSPCL Backend starting — env: {settings.ENVIRONMENT}"
    )

    yield

    print(
        "PSPCL Backend shutting down"
    )


# =========================================================
# APP
# =========================================================

app = FastAPI(
    title="PSPCL Meter Reading API",
    version="1.0.0",
    description=(
        "Backend for PSPCL offline-first "
        "meter reading system"
    ),
    lifespan=lifespan,
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,

    allow_origins=settings.CORS_ORIGINS,

    # Flutter's web dev server (flutter run -d chrome) picks a
    # random port every launch, so a fixed origin list in
    # CORS_ORIGINS constantly falls out of date in development.
    # Allow any localhost/127.0.0.1 port in dev only — production
    # still relies solely on the explicit CORS_ORIGINS allowlist.
    allow_origin_regex=(
        r"http://(localhost|127\.0\.0\.1):\d+"
        if settings.ENVIRONMENT == "development"
        else None
    ),

    allow_credentials=True,

    allow_methods=["*"],

    allow_headers=["*"],
)


# =========================================================
# ROUTERS
# =========================================================


# Authentication
app.include_router(
    auth.router
)


# Users / Officers
app.include_router(
    users.router
)


# Consumers
app.include_router(
    consumer.router
)


# Meter Readings
app.include_router(
    readings.router
)


# Images
app.include_router(
    images.router
)


# Offline Sync
app.include_router(
    sync.router
)


# Dashboard
app.include_router(
    dashboard.router
)


# Anomaly Detection
app.include_router(
    anomalies.router
)


# LCR Cases
app.include_router(
    lcr.router
)


# Notifications
app.include_router(
    notifications.router
)


# OCR
app.include_router(
    ocr.router
)


# =========================================================
# HEALTH CHECK
# =========================================================

@app.get("/health")
def health():

    return {
        "status": "ok",
        "version": settings.APP_VERSION,
    }