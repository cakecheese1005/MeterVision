"""
app/services/anomaly_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.anomaly import (
    AnomalyCreate,
    AnomalyUpdate,
    AnomalyResponse,
)



class AnomalyService:


    def __init__(
        self,
        db: Client
    ):
        self.db = db



    # =====================================================
    # CREATE ANOMALY
    # =====================================================

    def create_anomaly(
        self,
        request: AnomalyCreate,
    ) -> AnomalyResponse:


        response = (
            self.db
            .table("anomalies")
            .insert(
                {
                    "reading_id":
                        request.reading_id,

                    "anomaly_type":
                        "meter_reading",

                    "reason":
                        request.reason,

                    "severity":
                        request.severity,

                    "status":
                        request.status.value,

                    "detected_by":
                        "system",
                }
            )
            .execute()
        )


        if not response.data:
            raise bad_request(
                "Unable to create anomaly."
            )


        return self._to_response(
            response.data[0]
        )




    # =====================================================
    # GET ALL
    # =====================================================

    def list_anomalies(
        self,
    ):


        response = (
            self.db
            .table("anomalies")
            .select("*")
            .order(
                "created_at",
                desc=True,
            )
            .execute()
        )


        return [
            self._to_response(row)
            for row in (
                response.data or []
            )
        ]




    # =====================================================
    # GET ONE
    # =====================================================

    def get_anomaly(
        self,
        anomaly_id: str,
    ):


        response = (
            self.db
            .table("anomalies")
            .select("*")
            .eq(
                "id",
                anomaly_id,
            )
            .limit(1)
            .execute()
        )


        if not response.data:
            raise not_found(
                "Anomaly not found."
            )


        return self._to_response(
            response.data[0]
        )




    # =====================================================
    # UPDATE / RESOLVE
    # =====================================================

    def update_anomaly(
        self,
        anomaly_id: str,
        request: AnomalyUpdate,
    ):


        update_data = {}


        if request.reason is not None:
            update_data["reason"] = (
                request.reason
            )


        if request.severity is not None:
            update_data["severity"] = (
                request.severity
            )


        if request.status is not None:

            update_data["status"] = (
                request.status.value
            )


            if request.status.value == "resolved":

                update_data["resolved_at"] = (
                    datetime.now(
                        timezone.utc
                    ).isoformat()
                )


        if not update_data:

            return self.get_anomaly(
                anomaly_id
            )



        response = (
            self.db
            .table("anomalies")
            .update(update_data)
            .eq(
                "id",
                anomaly_id,
            )
            .execute()
        )


        if not response.data:
            raise bad_request(
                "Unable to update anomaly."
            )


        return self._to_response(
            response.data[0]
        )




    # =====================================================
    # HELPER
    # =====================================================

    def _to_response(
        self,
        anomaly: dict,
    ) -> AnomalyResponse:


        return AnomalyResponse(

            id=str(
                anomaly["id"]
            ),

            reading_id=str(
                anomaly["reading_id"]
            ),

            reason=anomaly.get(
                "reason"
            ),

            severity=anomaly.get(
                "severity"
            ),

            status=anomaly["status"],

            created_at=anomaly["created_at"],
        )