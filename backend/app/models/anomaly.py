from datetime import datetime

from pydantic import BaseModel

from app.models.enums import AnomalyStatus


class AnomalyCreate(BaseModel):
    reading_id: str
    reason: str
    severity: str
    status: AnomalyStatus = AnomalyStatus.PENDING


class AnomalyUpdate(BaseModel):
    reason: str | None = None
    severity: str | None = None
    status: AnomalyStatus | None = None


class AnomalyResponse(BaseModel):
    id: str
    reading_id: str
    reason: str
    severity: str
    status: AnomalyStatus
    created_at: datetime