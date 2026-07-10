from fastapi import APIRouter
from app.core.deps import get_supabase

router = APIRouter(
    prefix="/sync",
    tags=["Sync"]
)


@router.get("/pending")
def pending_sync():

    db = get_supabase()

    result = db.table(
        "sync_queue"
    ).select("*").eq(
        "sync_status",
        "PENDING"
    ).execute()

    return result.data


@router.post("/mark-synced/{sync_id}")
def mark_synced(sync_id: str):

    db = get_supabase()

    result = db.table(
        "sync_queue"
    ).update(
        {
            "sync_status": "SYNCED"
        }
    ).eq(
        "id",
        sync_id
    ).execute()

    return result.data