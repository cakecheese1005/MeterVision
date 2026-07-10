from fastapi import APIRouter
from app.core.deps import get_supabase

router = APIRouter(
    prefix="/dashboard",
    tags=["Dashboard"]
)


@router.get("/summary")
def dashboard_summary():

    db = get_supabase()

    readings = db.table(
        "readings"
    ).select("*", count="exact").execute()

    anomalies = db.table(
        "anomalies"
    ).select("*", count="exact").execute()

    lcr = db.table(
        "lcr_cases"
    ).select("*", count="exact").eq(
        "status",
        "OPEN"
    ).execute()

    return {
        "total_readings": readings.count,
        "total_anomalies": anomalies.count,
        "pending_lcr": lcr.count
    }