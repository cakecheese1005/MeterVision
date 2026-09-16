"""
app/services/sync_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.sync import (
    SyncRequest,
    BulkSyncRequest,
    SyncQueueResponse,
)


class SyncService:

    def __init__(self, db: Client):
        self.db = db


    # =========================================================
    # SYNC SINGLE OFFLINE READING
    # =========================================================

    def sync_reading(
        self,
        request: SyncRequest,
        officer_id: str,
        device_id: str | None = None,
    ) -> SyncQueueResponse:


        reading = request.reading


        # ---------------------------------------------
        # Validate consumer
        # ---------------------------------------------

        consumer_response = (
            self.db
            .table("consumers")
            .select(
                "id, previous_reading"
            )
            .eq(
                "id",
                reading.consumer_id,
            )
            .limit(1)
            .execute()
        )


        if not consumer_response.data:
            raise not_found(
                "Consumer not found."
            )


        consumer = consumer_response.data[0]


        previous_reading = (
            consumer.get(
                "previous_reading"
            )
        )


        units_consumed = None


        if previous_reading is not None:

            units_consumed = max(
                0,
                float(reading.reading_value)
                -
                float(previous_reading)
            )



        # ---------------------------------------------
        # Insert meter reading
        # ---------------------------------------------

        reading_payload = {

            "consumer_id":
            reading.consumer_id,

            "officer_id":
            officer_id,

            "reading_value":
            reading.reading_value,

            "previous_reading":
            previous_reading,

            "units_consumed":
            units_consumed,

            "latitude":
            reading.latitude,

            "longitude":
            reading.longitude,

            "captured_at":
            reading.captured_at.isoformat(),

            "reading_status":
            "pending",
        }


        reading_response = (
            self.db
            .table("meter_readings")
            .insert(
                reading_payload
            )
            .execute()
        )


        if not reading_response.data:
            raise bad_request(
                "Unable to create reading during sync."
            )


        reading_id = str(
            reading_response.data[0]["id"]
        )



        # ---------------------------------------------
        # Insert sync queue
        # ---------------------------------------------

        now = datetime.now(
            timezone.utc
        ).isoformat()


        sync_response = (
            self.db
            .table("sync_queue")
            .insert(
                {

                    "reading_id":
                    reading_id,

                    "device_id":
                    device_id,

                    "sync_status":
                    "success",

                    "retry_count":
                    0,

                    "last_attempt":
                    now,

                    "synced_at":
                    now,

                }
            )
            .execute()
        )


        if not sync_response.data:
            raise bad_request(
                "Unable to create sync record."
            )


        return self._sync_to_response(
            sync_response.data[0]
        )



    # =========================================================
    # BULK SYNC
    # =========================================================

    def bulk_sync(
        self,
        request: BulkSyncRequest,
        officer_id: str,
        device_id: str | None = None,
    ) -> list[SyncQueueResponse]:


        result = []


        for reading in request.readings:

            response = self.sync_reading(
                SyncRequest(
                    reading=reading
                ),
                officer_id,
                device_id,
            )

            result.append(response)


        return result



    # =========================================================
    # GET PENDING
    # =========================================================

    def get_pending_sync(
        self,
    ) -> list[SyncQueueResponse]:


        response = (
            self.db
            .table("sync_queue")
            .select("*")
            .eq(
                "sync_status",
                "pending",
            )
            .order(
                "created_at",
                desc=False,
            )
            .execute()
        )


        return [
            self._sync_to_response(row)
            for row in (
                response.data or []
            )
        ]



    # =========================================================
    # RETRY FAILED
    # =========================================================

    def retry_failed_sync(
        self,
    ) -> list[SyncQueueResponse]:


        response = (
            self.db
            .table("sync_queue")
            .select("*")
            .eq(
                "sync_status",
                "failed",
            )
            .execute()
        )


        result = []


        for sync in response.data or []:


            updated = (
                self.db
                .table("sync_queue")
                .update(
                    {

                        "sync_status":
                        "pending",

                        "retry_count":
                        sync.get(
                            "retry_count",
                            0
                        ) + 1,

                        "last_attempt":
                        datetime.now(
                            timezone.utc
                        ).isoformat(),

                    }
                )
                .eq(
                    "id",
                    sync["id"]
                )
                .execute()
            )


            if updated.data:

                result.append(
                    self._sync_to_response(
                        updated.data[0]
                    )
                )


        return result



    # =========================================================
    # MARK SUCCESS
    # =========================================================

    def mark_synced(
        self,
        sync_id: str,
    ) -> SyncQueueResponse:


        existing = (
            self.db
            .table("sync_queue")
            .select("*")
            .eq(
                "id",
                sync_id,
            )
            .maybe_single()
            .execute()
        )


        if not existing.data:
            raise not_found(
                "Sync record not found."
            )


        now = datetime.now(
            timezone.utc
        ).isoformat()


        response = (
            self.db
            .table("sync_queue")
            .update(
                {

                    "sync_status":
                    "success",

                    "synced_at":
                    now,

                    "last_attempt":
                    now,

                }
            )
            .eq(
                "id",
                sync_id,
            )
            .execute()
        )


        return self._sync_to_response(
            response.data[0]
        )



    # =========================================================
    # MARK FAILED
    # =========================================================

    def mark_failed(
        self,
        sync_id: str,
    ) -> SyncQueueResponse:


        existing = (
            self.db
            .table("sync_queue")
            .select("*")
            .eq(
                "id",
                sync_id,
            )
            .maybe_single()
            .execute()
        )


        if not existing.data:
            raise not_found(
                "Sync record not found."
            )


        response = (
            self.db
            .table("sync_queue")
            .update(
                {

                    "sync_status":
                    "failed",

                    "retry_count":
                    existing.data.get(
                        "retry_count",
                        0
                    ) + 1,

                    "last_attempt":
                    datetime.now(
                        timezone.utc
                    ).isoformat(),

                }
            )
            .eq(
                "id",
                sync_id,
            )
            .execute()
        )


        return self._sync_to_response(
            response.data[0]
        )



    # =========================================================
    # HELPER
    # =========================================================

    def _sync_to_response(
        self,
        sync: dict,
    ) -> SyncQueueResponse:


        return SyncQueueResponse(

            id=str(
                sync["id"]
            ),

            device_id=
            sync.get(
                "device_id"
            ),

            reading_id=str(
                sync["reading_id"]
            ),

            status=
            sync["sync_status"],

            retry_count=
            sync.get(
                "retry_count",
                0,
            ),

            created_at=
            sync["created_at"],

        )