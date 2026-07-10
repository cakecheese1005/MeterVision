from datetime import datetime, date
from typing import Any, List, Optional

from pydantic import BaseModel, Field

from app.models.enums import SortOrder


class APIResponse(BaseModel):
    success: bool = True
    message: str
    data: Optional[Any] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ErrorResponse(BaseModel):
    success: bool = False
    status_code: int
    message: str
    errors: Optional[List[str]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class SuccessResponse(BaseModel):
    success: bool = True
    message: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class PaginationRequest(BaseModel):
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


class PaginationResponse(BaseModel):
    page: int
    page_size: int
    total_records: int
    total_pages: int
    has_next: bool
    has_previous: bool


class SearchRequest(BaseModel):
    query: str = Field(default="", max_length=100)
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


class SortRequest(BaseModel):
    sort_by: str = "created_at"
    order: SortOrder = SortOrder.DESC


class DateRangeFilter(BaseModel):
    from_date: Optional[date] = None
    to_date: Optional[date] = None


class BulkDeleteRequest(BaseModel):
    ids: List[str] = Field(..., min_length=1)


class BulkActionRequest(BaseModel):
    ids: List[str] = Field(..., min_length=1)
    action: str


class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    database: str