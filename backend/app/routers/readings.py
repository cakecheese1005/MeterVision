from fastapi import APIRouter, Depends, status

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.reading import (
    ReadingCreate,
    ReadingUpdate,
    ReadingApproval,
    ReadingFilter,
    BulkAssignment,
)

from app.services.reading_service import ReadingService


router = APIRouter(
    prefix="/readings",
    tags=["Readings"],
)


def get_reading_service(
    db: Client = Depends(get_supabase),
) -> ReadingService:
    return ReadingService(db)


# =========================================================
# CREATE
# =========================================================

@router.post(
    "/create",
    status_code=status.HTTP_201_CREATED,
)
def create_reading(
    request: ReadingCreate,
    current_user: dict = Depends(get_current_user),
    service: ReadingService = Depends(get_reading_service),
):

    return service.create_reading(
        request,
        current_user["sub"],
    )


# =========================================================
# LIST
# =========================================================

@router.get("/")
def list_readings(
    status=None,
    officer_id: str | None = None,
    subdivision: str | None = None,
    from_date=None,
    to_date=None,
    service: ReadingService = Depends(get_reading_service),
):

    filters = ReadingFilter(
        status=status,
        officer_id=officer_id,
        subdivision=subdivision,
        from_date=from_date,
        to_date=to_date,
    )

    return service.list_readings(filters)


# =========================================================
# GET ONE
# =========================================================

@router.get("/{reading_id}")
def get_reading(
    reading_id: str,
    service: ReadingService = Depends(get_reading_service),
):

    return service.get_reading(reading_id)


# =========================================================
# GET DETAILS
# =========================================================

@router.get("/{reading_id}/details")
def get_reading_details(
    reading_id: str,
    service: ReadingService = Depends(get_reading_service),
):

    return service.get_reading_details(reading_id)


# =========================================================
# UPDATE
# =========================================================

@router.put("/{reading_id}")
def update_reading(
    reading_id: str,
    request: ReadingUpdate,
    service: ReadingService = Depends(get_reading_service),
):

    return service.update_reading(
        reading_id,
        request,
    )


# =========================================================
# APPROVE
# =========================================================

@router.post("/{reading_id}/approve")
def approve_reading(
    reading_id: str,
    request: ReadingApproval,
    service: ReadingService = Depends(get_reading_service),
):

    return service.approve_reading(
        reading_id,
        request,
    )


# =========================================================
# REJECT
# =========================================================

@router.post("/{reading_id}/reject")
def reject_reading(
    reading_id: str,
    request: ReadingApproval,
    service: ReadingService = Depends(get_reading_service),
):

    return service.reject_reading(
        reading_id,
        request,
    )


# =========================================================
# BULK ASSIGN
# =========================================================

@router.post("/bulk-assign")
def bulk_assign(
    request: BulkAssignment,
    service: ReadingService = Depends(get_reading_service),
):

    return service.bulk_assign(request)


# =========================================================
# UNITS
# =========================================================

@router.get("/{reading_id}/units")
def calculate_units(
    reading_id: str,
    service: ReadingService = Depends(get_reading_service),
):

    return service.calculate_units(reading_id)


# =========================================================
# ANOMALY CHECK
# =========================================================

@router.get("/{reading_id}/anomaly")
def detect_anomaly(
    reading_id: str,
    service: ReadingService = Depends(get_reading_service),
):

    return service.detect_anomaly(reading_id)