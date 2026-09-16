from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.enums import (
    AIClassification,
    OCRStatus,
)


# =========================================================
# SAVE OCR RESULT
# =========================================================

class OCRResultCreate(BaseModel):

    reading_id: str

    # Meter readings are digit sequences.
    # Keep them as strings.
    predicted_reading: Optional[str] = None

    # Confidence is between 0 and 1.
    confidence: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=1.0,
    )

    status: OCRStatus

    model_version: Optional[str] = None

    classification: Optional[AIClassification] = None


# =========================================================
# VERIFY / CORRECT OCR
# =========================================================

class OCRVerification(BaseModel):

    corrected_reading: str = Field(
        min_length=1,
        max_length=30,
    )

    remarks: Optional[str] = Field(
        default=None,
        max_length=500,
    )


# =========================================================
# OCR RESPONSE
# =========================================================

class OCRResultResponse(BaseModel):

    id: str

    reading_id: str

    predicted_reading: Optional[str] = None

    confidence: Optional[float] = None

    status: OCRStatus

    model_version: Optional[str] = None

    classification: Optional[AIClassification] = None

    processing_time_ms: Optional[int] = None

    processed_at: datetime

    verification_remarks: Optional[str] = None