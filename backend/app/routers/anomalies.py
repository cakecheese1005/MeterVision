from fastapi import APIRouter
from app.models.schemas import AnomalyCreate
from app.services.anomaly_service import create_anomaly

router = APIRouter(
    prefix="/anomalies",
    tags=["Anomalies"]
)


@router.post("/")
def add_anomaly(data: AnomalyCreate):

    result = create_anomaly(
        data.reading_id,
        data.reason,
        data.severity
    )

    return result.data