"""
app/services/reading_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.reading import (
    ReadingCreate,
    ReadingUpdate,
    ReadingApproval,
    ReadingResponse,
    ReadingDetailResponse,
    ReadingFilter,
    BulkAssignment,
)


class ReadingService:

    def __init__(self, db: Client):
        self.db = db

    # =========================================================
    # CREATE
    # =========================================================

    def create_reading(
        self,
        request: ReadingCreate,
        officer_id: str,
    ) -> ReadingResponse:

        consumer_response = (
            self.db
            .table("consumers")
            .select("id, previous_reading")
            .eq("id", request.consumer_id)
            .limit(1)
            .execute()
        )

        if not consumer_response.data:
            raise not_found("Consumer not found.")

        consumer = consumer_response.data[0]

        previous_reading = consumer.get("previous_reading")

        units_consumed = None

        if previous_reading is not None:
            units_consumed = max(
                0,
                float(request.reading_value)
                - float(previous_reading),
            )

        payload = {
            "consumer_id": request.consumer_id,
            "officer_id": officer_id,
            "reading_value": request.reading_value,
            "previous_reading": previous_reading,
            "units_consumed": units_consumed,
            "latitude": request.latitude,
            "longitude": request.longitude,
            "reading_status": "pending",
            "captured_at": request.captured_at.isoformat(),
        }

        response = (
            self.db
            .table("meter_readings")
            .insert(payload)
            .execute()
        )

        if not response.data:
            raise bad_request(
                "Unable to create meter reading."
            )

        return self._reading_to_response(
            response.data[0]
        )

    # =========================================================
    # READ ONE
    # =========================================================

    def get_reading(
        self,
        reading_id: str,
    ) -> ReadingResponse:

        reading = self._get_reading_record(reading_id)

        return self._reading_to_response(reading)

    # =========================================================
    # READ DETAILS
    # =========================================================

    def get_reading_details(
        self,
        reading_id: str,
    ) -> ReadingDetailResponse:

        reading = self._get_reading_record(reading_id)

        image_response = (
            self.db
            .table("meter_images")
            .select("*")
            .eq("reading_id", reading_id)
            .order("uploaded_at", desc=True)
            .limit(1)
            .execute()
        )

        ocr_response = (
            self.db
            .table("ocr_results")
            .select("*")
            .eq("reading_id", reading_id)
            .limit(1)
            .execute()
        )

        anomaly_response = (
            self.db
            .table("anomalies")
            .select("*")
            .eq("reading_id", reading_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

        from app.models.image import ImageResponse
        from app.models.ocr import OCRResultResponse
        from app.models.anomaly import AnomalyResponse

        image = None
        ocr = None
        anomaly = None

        if image_response.data:
            image = ImageResponse(
                id=str(image_response.data[0]["id"]),
                reading_id=str(
                    image_response.data[0]["reading_id"]
                ),
                image_url=image_response.data[0]["image_url"],
                quality=image_response.data[0]["image_quality"],
                classification=image_response.data[0].get(
                    "ai_classification"
                ),
                blur_score=image_response.data[0].get(
                    "blur_score"
                ),
                uploaded_at=image_response.data[0][
                    "uploaded_at"
                ],
            )

        if ocr_response.data:
            ocr = OCRResultResponse.model_validate(
                ocr_response.data[0]
            )

        if anomaly_response.data:
            anomaly = AnomalyResponse.model_validate(
                anomaly_response.data[0]
            )

        return ReadingDetailResponse(
            reading=self._reading_to_response(reading),
            image=image,
            ocr=ocr,
            anomaly=anomaly,
        )

    # =========================================================
    # LIST
    # =========================================================

    def list_readings(
        self,
        filters: ReadingFilter,
    ) -> list[ReadingResponse]:

        query = (
            self.db
            .table("meter_readings")
            .select("*")
        )

        if filters.status is not None:
            query = query.eq(
                "reading_status",
                filters.status.value,
            )

        if filters.officer_id:
            query = query.eq(
                "officer_id",
                filters.officer_id,
            )

        if filters.from_date:
            query = query.gte(
                "created_at",
                filters.from_date.isoformat(),
            )

        if filters.to_date:
            query = query.lte(
                "created_at",
                filters.to_date.isoformat(),
            )

        response = (
            query
            .order("created_at", desc=True)
            .execute()
        )

        return [
            self._reading_to_response(row)
            for row in (response.data or [])
        ]

    # =========================================================
    # UPDATE
    # =========================================================

    def update_reading(
        self,
        reading_id: str,
        request: ReadingUpdate,
    ) -> ReadingResponse:

        reading = self._get_reading_record(reading_id)

        update_data = {}

        # -----------------------------------------------------
        # Update reading value + recalculate units consumed
        # -----------------------------------------------------

        if request.reading_value is not None:

            update_data["reading_value"] = (
                request.reading_value
            )

            previous_reading = reading.get(
                "previous_reading"
            )

            if previous_reading is not None:
                update_data["units_consumed"] = max(
                    0,
                    float(request.reading_value)
                    - float(previous_reading),
                )

        # -----------------------------------------------------
        # Update GPS coordinates
        # -----------------------------------------------------

        if request.latitude is not None:
            update_data["latitude"] = request.latitude

        if request.longitude is not None:
            update_data["longitude"] = request.longitude

        # -----------------------------------------------------
        # Update reading status
        # -----------------------------------------------------

        if request.status is not None:
            update_data["reading_status"] = (
                request.status.value
            )

        # -----------------------------------------------------
        # Nothing to update
        # -----------------------------------------------------

        if not update_data:
            return self.get_reading(reading_id)

        # -----------------------------------------------------
        # Update timestamp
        # -----------------------------------------------------

        update_data["updated_at"] = (
            datetime.now(timezone.utc).isoformat()
        )

        # -----------------------------------------------------
        # Update Supabase
        # -----------------------------------------------------

        response = (
            self.db
            .table("meter_readings")
            .update(update_data)
            .eq("id", reading_id)
            .execute()
        )

        if not response.data:
            raise bad_request(
                "Unable to update reading."
            )

        return self._reading_to_response(
            response.data[0]
        )

    # =========================================================
    # APPROVE
    # =========================================================

    def approve_reading(
        self,
        reading_id: str,
        request: ReadingApproval,
    ) -> ReadingResponse:

        self._get_reading_record(reading_id)

        response = (
            self.db
            .table("meter_readings")
            .update(
                {
                    "reading_status": "completed",
                    "updated_at": datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .eq("id", reading_id)
            .execute()
        )

        if not response.data:
            raise bad_request(
                "Unable to approve reading."
            )

        return self._reading_to_response(
            response.data[0]
        )

    # =========================================================
    # REJECT
    # =========================================================

    def reject_reading(
        self,
        reading_id: str,
        request: ReadingApproval,
    ) -> ReadingResponse:

        self._get_reading_record(reading_id)

        response = (
            self.db
            .table("meter_readings")
            .update(
                {
                    "reading_status": "rejected",
                    "updated_at": datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .eq("id", reading_id)
            .execute()
        )

        if not response.data:
            raise bad_request(
                "Unable to reject reading."
            )

        return self._reading_to_response(
            response.data[0]
        )

    # =========================================================
    # BULK ASSIGN
    # =========================================================

    def bulk_assign(
        self,
        request: BulkAssignment,
    ):

        if not request.reading_ids:
            raise bad_request(
                "No reading IDs provided."
            )

        response = (
            self.db
            .table("meter_readings")
            .update(
                {
                    "officer_id": request.assigned_to,
                    "updated_at": datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .in_("id", request.reading_ids)
            .execute()
        )

        return response.data or []

    # =========================================================
    # CALCULATE UNITS
    # =========================================================

    def calculate_units(
        self,
        reading_id: str,
    ):

        reading = self._get_reading_record(reading_id)

        previous = reading.get("previous_reading")
        current = reading.get("reading_value")

        if previous is None:
            return {
                "reading_id": reading_id,
                "previous_reading": None,
                "reading_value": current,
                "units_consumed": None,
            }

        units = max(
            0,
            float(current) - float(previous),
        )

        return {
            "reading_id": reading_id,
            "previous_reading": previous,
            "reading_value": current,
            "units_consumed": units,
        }

    # =========================================================
    # DETECT ANOMALY
    # =========================================================

    def detect_anomaly(
        self,
        reading_id: str,
    ):

        reading = self._get_reading_record(reading_id)

        previous = reading.get("previous_reading")
        current = reading.get("reading_value")

        if previous is None:
            return {
                "reading_id": reading_id,
                "anomaly": False,
                "reason": None,
            }

        units = float(current) - float(previous)

        return {
            "reading_id": reading_id,
            "anomaly": units < 0,
            "reason": (
                "Current reading is lower than previous reading."
                if units < 0
                else None
            ),
        }

    # =========================================================
    # HELPERS
    # =========================================================

    def _get_reading_record(
        self,
        reading_id: str,
    ) -> dict:

        response = (
            self.db
            .table("meter_readings")
            .select("*")
            .eq("id", reading_id)
            .limit(1)
            .execute()
        )

        if not response.data:
            raise not_found("Reading not found.")

        return response.data[0]

    def _reading_to_response(
        self,
        reading: dict,
    ) -> ReadingResponse:

        return ReadingResponse(
            id=str(reading["id"]),
            consumer_id=str(
                reading["consumer_id"]
            ),
            officer_id=str(
                reading["officer_id"]
            ),
            reading_value=float(
                reading["reading_value"]
            ),
            previous_reading=(
                float(reading["previous_reading"])
                if reading.get("previous_reading") is not None
                else None
            ),
            units_consumed=(
                float(reading["units_consumed"])
                if reading.get("units_consumed") is not None
                else None
            ),
            status=reading["reading_status"],
            created_at=reading["created_at"],
        )