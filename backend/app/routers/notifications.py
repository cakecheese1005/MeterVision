from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.notification import (
    NotificationUpdate,
    NotificationResponse,
)

from app.services.notification_service import (
    NotificationService,
)



router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
)



def get_notification_service(
    db: Client = Depends(get_supabase),
):

    return NotificationService(db)



# =========================================================
# GET
# =========================================================

@router.get(
    "/",
    response_model=list[NotificationResponse],
)
def get_notifications(

    current_user: dict = Depends(
        get_current_user
    ),

    service: NotificationService = Depends(
        get_notification_service
    ),
):

    return service.get_notifications(
        current_user["sub"]
    )



# =========================================================
# MARK ONE READ
# =========================================================

@router.put(
    "/{notification_id}",
    response_model=NotificationResponse,
)
def mark_read(

    notification_id: str,

    request: NotificationUpdate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: NotificationService = Depends(
        get_notification_service
    ),
):

    return service.mark_as_read(
        notification_id,
        request,
    )



# =========================================================
# MARK ALL READ
# =========================================================

@router.put(
    "/read-all",
)
def mark_all_read(

    current_user: dict = Depends(
        get_current_user
    ),

    service: NotificationService = Depends(
        get_notification_service
    ),
):

    return service.mark_all_read(
        current_user["sub"]
    )