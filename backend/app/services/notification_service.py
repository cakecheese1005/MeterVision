"""
app/services/notification_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.notification import (
    NotificationResponse,
    NotificationUpdate,
)



class NotificationService:


    def __init__(
        self,
        db: Client,
    ):
        self.db = db



    # =========================================================
    # GET USER NOTIFICATIONS
    # =========================================================

    def get_notifications(
        self,
        user_id: str,
    ) -> list[NotificationResponse]:


        response = (
            self.db
            .table("notifications")
            .select("*")
            .eq(
                "user_id",
                user_id,
            )
            .order(
                "created_at",
                desc=True,
            )
            .execute()
        )


        return [

            self._notification_to_response(row)

            for row in (
                response.data or []
            )

        ]



    # =========================================================
    # MARK ONE READ
    # =========================================================

    def mark_as_read(
        self,
        notification_id: str,
        request: NotificationUpdate,
    ):


        response = (
            self.db
            .table("notifications")
            .update(
                {
                    "is_read":
                    request.is_read,

                    "updated_at":
                    datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .eq(
                "id",
                notification_id,
            )
            .execute()
        )


        if not response.data:
            raise not_found(
                "Notification not found."
            )


        return self._notification_to_response(
            response.data[0]
        )



    # =========================================================
    # MARK ALL READ
    # =========================================================

    def mark_all_read(
        self,
        user_id: str,
    ):


        response = (
            self.db
            .table("notifications")
            .update(
                {
                    "is_read": True,

                    "updated_at":
                    datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .eq(
                "user_id",
                user_id,
            )
            .execute()
        )


        return {
            "message":
            "All notifications marked as read."
        }



    # =========================================================
    # HELPER
    # =========================================================

    def _notification_to_response(
        self,
        notification: dict,
    ) -> NotificationResponse:


        return NotificationResponse(

            id=str(
                notification["id"]
            ),

            title=
            notification["title"],

            message=
            notification["message"],

            notification_type=
            notification["notification_type"],

            is_read=
            notification["is_read"],

            created_at=
            notification["created_at"],

        )