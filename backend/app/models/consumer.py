from typing import Optional

from pydantic import BaseModel

from app.models.enums import MeterType


# =========================================================
# CREATE
# =========================================================

class ConsumerCreate(BaseModel):

    consumer_number: str

    account_number: str

    consumer_name: str

    address: str

    meter_number: str

    meter_type: MeterType

    subdivision: Optional[str] = None

    feeder: Optional[str] = None

    cycle: Optional[str] = None



# =========================================================
# UPDATE
# =========================================================

class ConsumerUpdate(BaseModel):

    consumer_name: Optional[str] = None

    address: Optional[str] = None

    subdivision: Optional[str] = None

    feeder: Optional[str] = None

    cycle: Optional[str] = None



# =========================================================
# RESPONSE
# =========================================================

class ConsumerResponse(BaseModel):

    id: str

    consumer_number: str

    account_number: str

    consumer_name: str

    address: str

    meter_number: str

    meter_type: MeterType

    subdivision: Optional[str] = None

    feeder: Optional[str] = None

    cycle: Optional[str] = None



# =========================================================
# SEARCH
# =========================================================

class ConsumerSearchRequest(BaseModel):

    consumer_number: Optional[str] = None

    account_number: Optional[str] = None

    consumer_name: Optional[str] = None

    subdivision: Optional[str] = None