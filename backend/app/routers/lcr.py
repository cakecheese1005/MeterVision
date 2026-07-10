from fastapi import APIRouter
from app.core.deps import get_supabase
from app.models.schemas import LCRCaseCreate

router = APIRouter(
    prefix="/lcr",
    tags=["LCR"]
)


@router.post("/create")
def create_case(data: LCRCaseCreate):

    db = get_supabase()

    result = db.table(
        "lcr_cases"
    ).insert(
        {
            "reading_id": data.reading_id,
            "issue_type": data.issue_type,
            "remarks": data.remarks,
            "status": "OPEN"
        }
    ).execute()

    return result.data


@router.get("/all")
def get_cases():

    db = get_supabase()

    return db.table(
        "lcr_cases"
    ).select("*").execute().data