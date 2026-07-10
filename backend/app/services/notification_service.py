from app.core.deps import get_supabase


def create_notification(
    user_id: str,
    title: str,
    message: str
):
    db = get_supabase()

    return db.table(
        "notifications"
    ).insert(
        {
            "user_id": user_id,
            "title": title,
            "message": message
        }
    ).execute()