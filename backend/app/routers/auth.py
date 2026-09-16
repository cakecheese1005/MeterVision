from fastapi import APIRouter, Depends, status

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.auth import (
    LoginRequest,
    LoginData,
    RegisterUserRequest,
    RegisterUserData,
    UpdateProfileRequest,
    UserProfile,
    ChangePasswordRequest,
    RefreshSessionRequest,
    RefreshSessionData,
)

from app.models.common import APIResponse, SuccessResponse

from app.services.auth_service import AuthService


router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)


def get_auth_service(
    db: Client = Depends(get_supabase),
) -> AuthService:

    return AuthService(db)


# =========================================================
# LOGIN
# =========================================================

@router.post(
    "/login",
    response_model=APIResponse,
    status_code=status.HTTP_200_OK,
)
def login(
    request: LoginRequest,
    service: AuthService = Depends(get_auth_service),
):

    data = service.login(request)

    return APIResponse(
        success=True,
        message="Login successful.",
        data=data,
    )


# =========================================================
# LOGOUT
# =========================================================

@router.post(
    "/logout",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
)
def logout(
    current_user: dict = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):

    service.logout(
        current_user["sub"]
    )

    return SuccessResponse(
        success=True,
        message="Logout successful.",
    )


# =========================================================
# REFRESH TOKEN
# =========================================================

@router.post(
    "/refresh",
    response_model=APIResponse,
    status_code=status.HTTP_200_OK,
)
def refresh_session(
    request: RefreshSessionRequest,
    service: AuthService = Depends(get_auth_service),
):

    data = service.refresh_session(request)

    return APIResponse(
        success=True,
        message="Session refreshed successfully.",
        data=data,
    )


# =========================================================
# REGISTER
# =========================================================

@router.post(
    "/register",
    response_model=APIResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(
    request: RegisterUserRequest,
    service: AuthService = Depends(get_auth_service),
):

    data = service.register_user(request)

    return APIResponse(
        success=True,
        message="User registered successfully.",
        data=data,
    )


# =========================================================
# CURRENT USER PROFILE
# =========================================================

@router.get(
    "/me",
    response_model=APIResponse,
    status_code=status.HTTP_200_OK,
)
def get_profile(
    current_user: dict = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):

    profile = service.get_profile(
        current_user["sub"]
    )

    return APIResponse(
        success=True,
        message="Profile fetched successfully.",
        data=profile,
    )


# =========================================================
# UPDATE PROFILE
# =========================================================

@router.put(
    "/profile",
    response_model=APIResponse,
    status_code=status.HTTP_200_OK,
)
def update_profile(
    request: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):

    profile = service.update_profile(
        current_user["sub"],
        request,
    )

    return APIResponse(
        success=True,
        message="Profile updated successfully.",
        data=profile,
    )


# =========================================================
# CHANGE PASSWORD
# =========================================================

@router.put(
    "/password",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
)
def change_password(
    request: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):

    service.change_password(
        current_user["sub"],
        request,
    )

    return SuccessResponse(
        success=True,
        message="Password changed successfully.",
    )