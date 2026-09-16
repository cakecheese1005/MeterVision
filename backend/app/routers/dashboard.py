from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.dashboard import (
    DashboardFilter,
    DashboardResponse,
)

from app.services.dashboard_service import (
    DashboardService,
)


router = APIRouter(
    prefix="/dashboard",
    tags=["Dashboard"],
)


def get_dashboard_service(
    db: Client = Depends(get_supabase),
) -> DashboardService:

    return DashboardService(db)


# =========================================================
# GET DASHBOARD SUMMARY
# =========================================================

@router.get(
    "",
    response_model=DashboardResponse,
)
def get_dashboard(
    filters: DashboardFilter = Depends(),
    current_user: dict = Depends(get_current_user),
    service: DashboardService = Depends(
        get_dashboard_service
    ),
):

    return service.get_dashboard(filters)