"""
app/services/audit_service.py
"""

from supabase import Client


class AuditService:

    def __init__(self, db: Client):
        self.db = db

    # ---------------------------------------------------------
    # Audit Logs
    # ---------------------------------------------------------

    def log_action(
        self,
        user_id: str,
        action: str,
        module: str,
        description: str,
    ):
        ...

    def get_logs(self):
        ...