"""
app/services/ocr_service.py

Server-side OCR orchestration.

Flow:

meter_images
    ↓
download stored image
    ↓
AIService
    ├── EasyOCR
    ├── reading-region detection
    ├── trained digit model
    ├── blur/glare checks
    └── image classification
    ↓
determine OCR status
    ↓
save / update OCR result
    ↓
update meter_images
"""

import time

import requests

from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.enums import OCRStatus

from app.models.ocr import (
    OCRResultCreate,
    OCRVerification,
    OCRResultResponse,
)

from app.services.ai_service import (
    AIService,
)


# =========================================================
# CONSTANTS
# =========================================================

OCR_LOW_CONFIDENCE_THRESHOLD = 0.70


# =========================================================
# SERVICE
# =========================================================

class OCRService:

    def __init__(
        self,
        db: Client,
    ):

        self.db = db

        # AIService internally caches
        # EasyOCR and trained model instances.
        self.ai_service = AIService()

    # =========================================================
    # PROCESS IMAGE
    # =========================================================

    def process_image(
        self,
        image_id: str,
    ) -> OCRResultResponse:

        start_time = time.time()

        # -----------------------------------------------------
        # Get image
        # -----------------------------------------------------

        image_response = (
            self.db
            .table("meter_images")
            .select("*")
            .eq(
                "id",
                image_id,
            )
            .limit(1)
            .execute()
        )

        if not image_response.data:

            raise not_found(
                "Image not found."
            )

        image = image_response.data[0]

        reading_id = str(
            image["reading_id"]
        )

        image_url = image.get(
            "image_url"
        )

        if not image_url:

            raise bad_request(
                "Image URL not found."
            )

        # -----------------------------------------------------
        # Download image
        # -----------------------------------------------------

        try:

            response = requests.get(
                image_url,
                timeout=30,
            )

            response.raise_for_status()

            image_bytes = response.content

        except requests.RequestException as exc:

            raise bad_request(
                f"Unable to download image: {exc}"
            )

        if not image_bytes:

            raise bad_request(
                "Downloaded image is empty."
            )

        # -----------------------------------------------------
        # Run AI pipeline
        # -----------------------------------------------------

        try:

            result = (
                self.ai_service
                .process_image(
                    image_bytes
                )
            )

        except Exception as exc:

            raise bad_request(
                f"AI processing failed: {exc}"
            )

        # -----------------------------------------------------
        # Extract AI result
        # -----------------------------------------------------

        predicted_reading = (
            result.get("reading")
        )

        confidence = (
            result.get(
                "reading_confidence"
            )
        )

        classification = (
            result.get(
                "classification"
            )
        )

        model_version = (
            result.get(
                "model_version"
            )
            or "digit-reader-v1"
        )

        # -----------------------------------------------------
        # Determine OCR status
        #
        # success:
        #   valid reading + confidence >= 0.70
        #
        # low_confidence:
        #   missing reading OR confidence < 0.70
        #
        # failed:
        #   reserved for actual processing failures
        #   handled by exception above
        # -----------------------------------------------------

        if (
            predicted_reading is not None
            and confidence is not None
            and float(confidence)
                >= OCR_LOW_CONFIDENCE_THRESHOLD
        ):

            status = OCRStatus.SUCCESS.value

        else:

            status = OCRStatus.LOW_CONFIDENCE.value

        # -----------------------------------------------------
        # Processing time
        # -----------------------------------------------------

        processing_time = int(
            (
                time.time()
                - start_time
            )
            * 1000
        )

        # -----------------------------------------------------
        # OCR payload
        # -----------------------------------------------------

        payload = {

            "reading_id":
                reading_id,

            "predicted_reading":
                (
                    str(predicted_reading)
                    if predicted_reading is not None
                    else None
                ),

            "confidence":
                (
                    float(confidence)
                    if confidence is not None
                    else None
                ),

            "status":
                status,

            "model_version":
                model_version,

            "classification":
                classification,

            "processing_time_ms":
                processing_time,

        }

        # -----------------------------------------------------
        # Check whether OCR already exists
        #
        # reading_id is UNIQUE in DB.
        #
        # Therefore re-processing an image should UPDATE
        # the existing OCR result instead of causing a
        # duplicate-key error.
        # -----------------------------------------------------

        existing_response = (
            self.db
            .table("ocr_results")
            .select("*")
            .eq(
                "reading_id",
                reading_id,
            )
            .limit(1)
            .execute()
        )

        if existing_response.data:

            existing_id = (
                existing_response.data[0]["id"]
            )

            ocr_response = (
                self.db
                .table("ocr_results")
                .update(payload)
                .eq(
                    "id",
                    existing_id,
                )
                .execute()
            )

        else:

            ocr_response = (
                self.db
                .table("ocr_results")
                .insert(payload)
                .execute()
            )

        if not ocr_response.data:

            raise bad_request(
                "Unable to save OCR result."
            )

        # -----------------------------------------------------
        # Update meter image AI information
        # -----------------------------------------------------

        image_update = {

            "blur_score":
                result.get(
                    "blur_score"
                ),

            "ai_classification":
                classification,
        }

        category = result.get(
            "classification_category"
        )

        if category == "blur":

            image_update[
                "image_quality"
            ] = "blur"

        elif category == "reflection":

            image_update[
                "image_quality"
            ] = "reflection"

        elif category == "irrelevant":

            image_update[
                "image_quality"
            ] = "irrelevant"

        else:

            image_update[
                "image_quality"
            ] = "ok"

        try:

            (
                self.db
                .table("meter_images")
                .update(image_update)
                .eq(
                    "id",
                    image_id,
                )
                .execute()
            )

        except Exception:
            # OCR result has already been saved.
            # Image metadata failure should not destroy
            # the OCR response.
            pass

        # -----------------------------------------------------
        # Return response
        # -----------------------------------------------------

        return self._ocr_to_response(
            ocr_response.data[0]
        )

    # =========================================================
    # SAVE OCR RESULT MANUALLY
    # =========================================================

    def save_result(
        self,
        request: OCRResultCreate,
    ) -> OCRResultResponse:

        payload = request.model_dump(
            mode="json"
        )

        response = (
            self.db
            .table("ocr_results")
            .insert(payload)
            .execute()
        )

        if not response.data:

            raise bad_request(
                "Unable to save OCR result."
            )

        return self._ocr_to_response(
            response.data[0]
        )

    # =========================================================
    # VERIFY / CORRECT OCR RESULT
    # =========================================================

    def verify_result(
        self,
        ocr_id: str,
        request: OCRVerification,
    ) -> OCRResultResponse:

        existing = (
            self.db
            .table("ocr_results")
            .select("*")
            .eq(
                "id",
                ocr_id,
            )
            .limit(1)
            .execute()
        )

        if not existing.data:

            raise not_found(
                "OCR result not found."
            )

        update_payload = {

            "predicted_reading":
                request.corrected_reading,

            "status":
                OCRStatus.VERIFIED.value,

            "verification_remarks":
                request.remarks,
        }

        updated = (
            self.db
            .table("ocr_results")
            .update(update_payload)
            .eq(
                "id",
                ocr_id,
            )
            .execute()
        )

        if not updated.data:

            raise bad_request(
                "Unable to verify OCR."
            )

        # -----------------------------------------------------
        # Update actual meter reading
        #
        # OCR correction should not leave the main reading
        # table with the old value.
        # -----------------------------------------------------

        reading_id = str(
            existing.data[0]["reading_id"]
        )

        try:

            reading_value = float(
                request.corrected_reading
            )

            reading_response = (
                self.db
                .table("meter_readings")
                .select(
                    "previous_reading"
                )
                .eq(
                    "id",
                    reading_id,
                )
                .limit(1)
                .execute()
            )

            if reading_response.data:

                previous_reading = (
                    reading_response.data[0]
                    .get("previous_reading")
                )

                reading_update = {
                    "reading_value":
                        reading_value,
                }

                if previous_reading is not None:

                    reading_update[
                        "units_consumed"
                    ] = max(
                        0,
                        reading_value
                        - float(previous_reading),
                    )

                (
                    self.db
                    .table("meter_readings")
                    .update(reading_update)
                    .eq(
                        "id",
                        reading_id,
                    )
                    .execute()
                )

        except (
            ValueError,
            TypeError,
            Exception,
        ):
            # OCR verification itself has already succeeded.
            # Do not lose the correction because updating the
            # meter reading failed.
            pass

        return self._ocr_to_response(
            updated.data[0]
        )

    # =========================================================
    # GET OCR RESULT BY READING
    # =========================================================

    def get_result(
        self,
        reading_id: str,
    ) -> OCRResultResponse:

        response = (
            self.db
            .table("ocr_results")
            .select("*")
            .eq(
                "reading_id",
                reading_id,
            )
            .limit(1)
            .execute()
        )

        if not response.data:

            raise not_found(
                "OCR result not found."
            )

        return self._ocr_to_response(
            response.data[0]
        )

    # =========================================================
    # HELPER
    # =========================================================

    def _ocr_to_response(
        self,
        row: dict,
    ) -> OCRResultResponse:

        return OCRResultResponse(

            id=str(
                row["id"]
            ),

            reading_id=str(
                row["reading_id"]
            ),

            predicted_reading=(
                str(
                    row["predicted_reading"]
                )
                if row.get(
                    "predicted_reading"
                ) is not None
                else None
            ),

            confidence=(
                float(
                    row["confidence"]
                )
                if row.get(
                    "confidence"
                ) is not None
                else None
            ),

            status=row["status"],

            model_version=row.get(
                "model_version"
            ),

            classification=row.get(
                "classification"
            ),

            processing_time_ms=row.get(
                "processing_time_ms"
            ),

            processed_at=row[
                "processed_at"
            ],

            verification_remarks=row.get(
                "verification_remarks"
            ),
        )