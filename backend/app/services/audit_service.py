def log(db, actor_id, action,
        target_id=None,
        target_type=None,
        metadata=None):
    try:
        db.table("audit_logs").insert({
            "actor_id": actor_id,
            "action": action,
            "target_id": target_id,
            "target_type": target_type,
            "metadata": metadata or {}
        }).execute()
    except Exception:
        pass