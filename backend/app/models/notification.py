from datetime import datetime

from pydantic import BaseModel

from app.models.enums import NotificationType


class NotificationResponse(BaseModel):
    id: str
    title: str
    message: str
    notification_type: NotificationType
    is_read: bool
    created_at: datetime


class NotificationUpdate(BaseModel):
    is_read: bool