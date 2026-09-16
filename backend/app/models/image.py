from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.enums import (
    AIClassification,
    ImageQuality,
)


# =========================================================
# IMAGE UPLOAD REQUEST
# =========================================================

class ImageUploadRequest(BaseModel):

    reading_id: str

    latitude: float

    longitude: float


# =========================================================
# IMAGE UPLOAD RESPONSE
# =========================================================

class ImageUploadResponse(BaseModel):

    image_id: str

    image_url: str

    blur_score: float

    quality: ImageQuality

    # AI classification is not available until
    # OCR/AI processing is performed.
    classification: Optional[AIClassification] = None


# =========================================================
# IMAGE RESPONSE
# =========================================================

class ImageResponse(BaseModel):

    id: str

    reading_id: str

    image_url: str

    quality: ImageQuality

    # AI classification may be NULL before
    # /ocr/process/{image_id} is called.
    classification: Optional[AIClassification] = None

    blur_score: Optional[float] = None

    uploaded_at: datetime