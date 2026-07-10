from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ==========================================================
# STANDARD API RESPONSE
# ==========================================================

class APIResponse(BaseModel):
    success: bool = True
    message: str
    data: Optional[Any] = None


# ==========================================================
# STANDARD ERROR RESPONSE
# ==========================================================

class ErrorResponse(BaseModel):
    success: bool = False
    message: str
    errors: Optional[List[str]] = None


# ==========================================================
# PAGINATION REQUEST
# ==========================================================

class PaginationRequest(BaseModel):
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


# ==========================================================
# PAGINATION RESPONSE
# ==========================================================

class PaginationResponse(BaseModel):
    page: int
    page_size: int
    total_records: int
    total_pages: int


# ==========================================================
# SEARCH REQUEST
# ==========================================================

class SearchRequest(BaseModel):
    query: str = ""
    page: int = 1
    page_size: int = 20


# ==========================================================
# SORT REQUEST
# ==========================================================

class SortRequest(BaseModel):
    sort_by: str = "created_at"
    order: str = "desc"


# ==========================================================
# DATE RANGE FILTER
# ==========================================================

class DateRangeFilter(BaseModel):
    from_date: Optional[str] = None
    to_date: Optional[str] = None


# ==========================================================
# BULK DELETE
# ==========================================================

class BulkDeleteRequest(BaseModel):
    ids: List[str]


# ==========================================================
# BULK ACTION
# ==========================================================

class BulkActionRequest(BaseModel):
    ids: List[str]
    action: str


# ==========================================================
# SUCCESS RESPONSE
# ==========================================================

class SuccessResponse(BaseModel):
    success: bool = True
    message: str


# ==========================================================
# HEALTH CHECK
# ==========================================================

class HealthResponse(BaseModel):
    status: str
    version: str