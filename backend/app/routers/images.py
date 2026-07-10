from fastapi import APIRouter
from app.core.deps import get_supabase

router = APIRouter(
    prefix="/images",
    tags=["Images"]
)


@router.get("/")
def get_images():

    db = get_supabase()

    result = db.table(
        "images"
    ).select("*").execute()

    return result.data