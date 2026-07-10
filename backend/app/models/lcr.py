from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.enums import LCRStatus


class AssignLCR(BaseModel):
    reading_id: str
    lcr_user_id: str


class LCRDecision(BaseModel):
    status: LCRStatus
    remarks: Optional[str] = None


class LCRCaseResponse(BaseModel):
    id: str
    reading_id: str
    assigned_to: Optional[str] = None
    status: LCRStatus
    remarks: Optional[str] = None
    updated_at: datetime