from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.enums import AIClassification, OCRStatus


class OCRResultCreate(BaseModel):
    reading_id: str
    predicted_reading: str
    confidence: float
    status: OCRStatus
    model_version: str
    classification: AIClassification


class OCRVerification(BaseModel):
    corrected_reading: str
    remarks: Optional[str] = None


class OCRResultResponse(BaseModel):
    id: str
    reading_id: str
    predicted_reading: str
    confidence: float
    status: OCRStatus
    model_version: str
    classification: AIClassification
    processed_at: datetime