from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.anomaly import (
    AnomalyCreate,
    AnomalyUpdate,
    AnomalyResponse,
)

from app.services.anomaly_service import (
    AnomalyService,
)



router = APIRouter(
    prefix="/anomalies",
    tags=["Anomalies"],
)



def get_anomaly_service(
    db: Client = Depends(get_supabase),
):

    return AnomalyService(db)




# =====================================================
# CREATE
# =====================================================

@router.post(
    "/",
    response_model=AnomalyResponse,
)
def create_anomaly(
    request: AnomalyCreate,
    current_user: dict = Depends(get_current_user),
    service: AnomalyService = Depends(
        get_anomaly_service
    ),
):

    return service.create_anomaly(
        request
    )




# =====================================================
# LIST
# =====================================================

@router.get(
    "/",
    response_model=list[AnomalyResponse],
)
def list_anomalies(
    current_user: dict = Depends(get_current_user),
    service: AnomalyService = Depends(
        get_anomaly_service
    ),
):

    return service.list_anomalies()




# =====================================================
# GET ONE
# =====================================================

@router.get(
    "/{anomaly_id}",
    response_model=AnomalyResponse,
)
def get_anomaly(
    anomaly_id: str,
    current_user: dict = Depends(get_current_user),
    service: AnomalyService = Depends(
        get_anomaly_service
    ),
):

    return service.get_anomaly(
        anomaly_id
    )




# =====================================================
# UPDATE
# =====================================================

@router.put(
    "/{anomaly_id}",
    response_model=AnomalyResponse,
)
def update_anomaly(
    anomaly_id: str,
    request: AnomalyUpdate,
    current_user: dict = Depends(get_current_user),
    service: AnomalyService = Depends(
        get_anomaly_service
    ),
):

    return service.update_anomaly(
        anomaly_id,
        request,
    )