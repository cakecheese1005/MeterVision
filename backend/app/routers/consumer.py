from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.consumer import (
    ConsumerCreate,
    ConsumerUpdate,
    ConsumerSearchRequest,
    ConsumerResponse,
)

from app.services.consumer_service import ConsumerService



router = APIRouter(
    prefix="/consumers",
    tags=["Consumers"],
)



def get_consumer_service(
    db: Client = Depends(get_supabase),
):

    return ConsumerService(db)



# =========================================================
# CREATE
# =========================================================

@router.post(
    "/",
    response_model=ConsumerResponse,
)
def create_consumer(

    request: ConsumerCreate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    return service.create_consumer(
        request
    )



# =========================================================
# LIST
# =========================================================

@router.get(
    "/",
    response_model=list[ConsumerResponse],
)
def get_consumers(

    page: int = 1,

    page_size: int = 20,

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    return service.get_all_consumers(
        page,
        page_size,
    )



# =========================================================
# SEARCH
# =========================================================

@router.post(
    "/search",
    response_model=list[ConsumerResponse],
)
def search_consumers(

    request: ConsumerSearchRequest,

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    return service.search_consumers(
        request
    )



# =========================================================
# GET ONE
# =========================================================

@router.get(
    "/{consumer_id}",
    response_model=ConsumerResponse,
)
def get_consumer(

    consumer_id: str,

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    return service.get_consumer(
        consumer_id
    )



# =========================================================
# UPDATE
# =========================================================

@router.put(
    "/{consumer_id}",
    response_model=ConsumerResponse,
)
def update_consumer(

    consumer_id: str,

    request: ConsumerUpdate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    return service.update_consumer(
        consumer_id,
        request,
    )



# =========================================================
# DELETE
# =========================================================

@router.delete(
    "/{consumer_id}",
)
def delete_consumer(

    consumer_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: ConsumerService = Depends(
        get_consumer_service
    ),
):

    service.delete_consumer(
        consumer_id
    )

    return {
        "message":
        "Consumer deleted successfully."
    }