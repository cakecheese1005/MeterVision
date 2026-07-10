from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.enums import UserRole


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

    user_id: str
    name: str
    email: EmailStr
    role: UserRole


class CurrentUser(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole


class RegisterUserRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8)
    role: UserRole


class RegisterUserData(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole
    created_at: datetime


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2)
    phone_number: Optional[str] = None


class UserProfile(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole
    phone_number: Optional[str] = None
    last_login: Optional[datetime] = None
    created_at: datetime


class ChangePasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=8)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    access_token: str
    new_password: str = Field(..., min_length=8)


class RefreshSessionRequest(BaseModel):
    refresh_token: str


class RefreshSessionData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthBaseModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        extra="ignore",
    )