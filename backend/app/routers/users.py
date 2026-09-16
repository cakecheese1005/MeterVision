from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.users import (
    UserCreate,
    UserUpdate,
    UserResponse,
)

from app.services.user_service import UserService



router = APIRouter(
    prefix="/users",
    tags=["Users"],
)



def get_user_service(
    db: Client = Depends(get_supabase),
):

    return UserService(db)



# =========================================================
# CREATE
# =========================================================

@router.post(
    "/",
    response_model=UserResponse,
)
def create_user(

    request: UserCreate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.create_user(
        request
    )



# =========================================================
# ALL USERS
# =========================================================

@router.get(
    "/",
    response_model=list[UserResponse],
)
def get_users(

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.get_users()



# =========================================================
# OFFICERS
# =========================================================

@router.get(
    "/officers",
    response_model=list[UserResponse],
)
def get_officers(

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.get_officers()



# =========================================================
# GET ONE
# =========================================================

@router.get(
    "/{user_id}",
    response_model=UserResponse,
)
def get_user(

    user_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.get_user(
        user_id
    )



# =========================================================
# UPDATE
# =========================================================

@router.put(
    "/{user_id}",
    response_model=UserResponse,
)
def update_user(

    user_id: str,

    request: UserUpdate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.update_user(
        user_id,
        request,
    )



# =========================================================
# DEACTIVATE
# =========================================================

@router.delete(
    "/{user_id}",
)
def delete_user(

    user_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: UserService = Depends(
        get_user_service
    ),

):

    return service.deactivate_user(
        user_id
    )