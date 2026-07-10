from fastapi import APIRouter
from app.core.deps import get_supabase
from app.models.schemas import ReadingCreate

router = APIRouter(
    prefix="/readings",
    tags=["Readings"]
)


@router.post("/create")
def create_reading(data: ReadingCreate):

    db = get_supabase()

    result = db.table(
        "readings"
    ).insert(
        {
            "consumer_id": data.consumer_id,
            "reading_value": data.reading_value,
            "status": "PENDING"
        }
    ).execute()

    return result.data


@router.get("/")
def get_readings():

    db = get_supabase()

    result = db.table(
        "readings"
    ).select("*").execute()

    return result.data