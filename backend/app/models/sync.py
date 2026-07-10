from datetime import datetime
from typing import List

from pydantic import BaseModel

from app.models.enums import SyncStatus


class OfflineReading(BaseModel):
    local_id: str
    consumer_id: str
    reading_value: float
    latitude: float
    longitude: float
    captured_at: datetime
    image_path: str


class SyncRequest(BaseModel):
    reading: OfflineReading


class BulkSyncRequest(BaseModel):
    readings: List[OfflineReading]


class SyncQueueResponse(BaseModel):
    id: str
    device_id: str
    reading_id: str
    status: SyncStatus
    retry_count: int
    created_at: datetime