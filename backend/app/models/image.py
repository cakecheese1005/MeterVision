from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.enums import AIClassification, ImageQuality


class ImageUploadRequest(BaseModel):
    reading_id: str
    latitude: float
    longitude: float


class ImageUploadResponse(BaseModel):
    image_id: str
    image_url: str
    blur_score: float
    quality: ImageQuality
    classification: AIClassification


class ImageResponse(BaseModel):
    id: str
    reading_id: str
    image_url: str
    quality: ImageQuality
    classification: AIClassification
    blur_score: Optional[float] = None
    uploaded_at: datetime