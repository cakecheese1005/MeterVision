from pydantic import BaseModel, EmailStr, Field

from app.models.enums import UserRole


class UserCreate(BaseModel):
    name: str = Field(..., min_length=2)
    email: EmailStr
    password: str = Field(..., min_length=8)
    role: UserRole


class UserUpdate(BaseModel):
    name: str | None = None
    role: UserRole | None = None


class UserResponse(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole