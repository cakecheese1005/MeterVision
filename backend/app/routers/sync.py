"""
app/routers/sync.py
"""

from fastapi import APIRouter, Depends

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.sync import (
    SyncRequest,
    BulkSyncRequest,
    SyncQueueResponse,
)

from app.services.sync_service import SyncService


router = APIRouter(
    prefix="/sync",
    tags=["Sync"],
)



def get_sync_service():

    db = get_supabase()

    return SyncService(db)



# =========================================================
# Sync one offline reading
# =========================================================

@router.post(
    "/",
    response_model=SyncQueueResponse,
)
def sync_reading(

    request: SyncRequest,

    device_id: str | None = None,

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.sync_reading(
        request=request,
        officer_id=current_user["sub"],
        device_id=device_id,
    )



# =========================================================
# Bulk sync
# =========================================================

@router.post(
    "/bulk",
    response_model=list[SyncQueueResponse],
)
def bulk_sync(

    request: BulkSyncRequest,

    device_id: str | None = None,

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.bulk_sync(
        request=request,
        officer_id=current_user["sub"],
        device_id=device_id,
    )



# =========================================================
# Pending sync queue
# =========================================================

@router.get(
    "/pending",
    response_model=list[SyncQueueResponse],
)
def pending_sync(

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.get_pending_sync()



# =========================================================
# Retry failed sync
# =========================================================

@router.post(
    "/retry-failed",
    response_model=list[SyncQueueResponse],
)
def retry_failed_sync(

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.retry_failed_sync()



# =========================================================
# Mark sync successful
# =========================================================

@router.post(
    "/mark-synced/{sync_id}",
    response_model=SyncQueueResponse,
)
def mark_synced(

    sync_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.mark_synced(
        sync_id
    )



# =========================================================
# Mark sync failed
# =========================================================

@router.post(
    "/mark-failed/{sync_id}",
    response_model=SyncQueueResponse,
)
def mark_failed(

    sync_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

):

    service = get_sync_service()


    return service.mark_failed(
        sync_id
    )