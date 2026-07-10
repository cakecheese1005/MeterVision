from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.enums import ReadingStatus
from app.models.image import ImageResponse
from app.models.ocr import OCRResultResponse
from app.models.anomaly import AnomalyResponse


class ReadingCreate(BaseModel):
    consumer_id: str
    reading_value: float
    latitude: float
    longitude: float
    captured_at: datetime


class ReadingUpdate(BaseModel):
    reading_value: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    status: Optional[ReadingStatus] = None


class ReadingApproval(BaseModel):
    status: ReadingStatus
    remarks: Optional[str] = None


class ReadingResponse(BaseModel):
    id: str
    consumer_id: str
    officer_id: str
    reading_value: float
    previous_reading: Optional[float] = None
    units_consumed: Optional[float] = None
    status: ReadingStatus
    created_at: datetime


class ReadingDetailResponse(BaseModel):
    reading: ReadingResponse
    image: Optional[ImageResponse] = None
    ocr: Optional[OCRResultResponse] = None
    anomaly: Optional[AnomalyResponse] = None


class BulkAssignment(BaseModel):
    reading_ids: List[str]
    assigned_to: str


class ReadingFilter(BaseModel):
    status: Optional[ReadingStatus] = None
    officer_id: Optional[str] = None
    subdivision: Optional[str] = None
    from_date: Optional[datetime] = None
    to_date: Optional[datetime] = None