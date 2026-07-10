from datetime import date
from typing import List, Optional

from pydantic import BaseModel


class DashboardFilter(BaseModel):
    from_date: Optional[date] = None
    to_date: Optional[date] = None
    subdivision: Optional[str] = None
    officer_id: Optional[str] = None


class DashboardSummary(BaseModel):
    total_consumers: int
    total_readings: int
    completed_today: int
    pending_readings: int
    anomalies: int
    pending_lcr: int
    offline_pending: int


class DashboardTrend(BaseModel):
    date: date
    readings: int
    anomalies: int


class DashboardResponse(BaseModel):
    summary: DashboardSummary
    trends: List[DashboardTrend]