from app.core.deps import get_supabase


def create_anomaly(
    reading_id: str,
    reason: str,
    severity: str
):
    db = get_supabase()

    return db.table(
        "anomalies"
    ).insert(
        {
            "reading_id": reading_id,
            "reason": reason,
            "severity": severity,
            "status": "OPEN"
        }
    ).execute()