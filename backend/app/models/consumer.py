from typing import Optional

from pydantic import BaseModel

from app.models.enums import MeterType


class ConsumerCreate(BaseModel):
    account_number: str
    consumer_name: str
    address: str
    meter_number: str
    meter_type: MeterType
    subdivision: Optional[str] = None
    feeder: Optional[str] = None
    cycle: Optional[str] = None


class ConsumerUpdate(BaseModel):
    consumer_name: Optional[str] = None
    address: Optional[str] = None
    subdivision: Optional[str] = None
    feeder: Optional[str] = None
    cycle: Optional[str] = None


class ConsumerResponse(BaseModel):
    id: str
    account_number: str
    consumer_name: str
    address: str
    meter_number: str
    meter_type: MeterType
    subdivision: Optional[str] = None
    feeder: Optional[str] = None
    cycle: Optional[str] = None


class ConsumerSearchRequest(BaseModel):
    account_number: Optional[str] = None
    consumer_name: Optional[str] = None
    subdivision: Optional[str] = None