"""
app/services/image_service.py

Handles meter-image upload and storage.

Image processing responsibility:

    Upload image
        ↓
    Calculate blur score
        ↓
    Store image
        ↓
    Save meter_images record
        ↓
    Return image_id

AI OCR/classification is performed separately by:

    POST /ocr/process/{image_id}

That endpoint uses AIService.
"""

from uuid import uuid4

from fastapi import UploadFile
from supabase import Client

from app.core.exceptions import (
    bad_request,
    not_found,
)

from app.models.image import (
    ImageUploadRequest,
    ImageUploadResponse,
    ImageResponse,
)

from app.services.blur_service import (
    BlurService,
)


class ImageService:

    def __init__(
        self,
        db: Client,
    ):

        self.db = db

        self.blur_service = (
            BlurService()
        )

    # =========================================================
    # UPLOAD IMAGE
    # =========================================================

    def upload_image(
        self,
        request: ImageUploadRequest,
        image_file: UploadFile,
    ) -> ImageUploadResponse:

        # -----------------------------------------------------
        # Check reading exists
        # -----------------------------------------------------

        reading = (
            self.db
            .table("meter_readings")
            .select("id")
            .eq(
                "id",
                request.reading_id,
            )
            .limit(1)
            .execute()
        )

        if not reading.data:

            raise not_found(
                "Reading not found."
            )

        # -----------------------------------------------------
        # Read image bytes
        # -----------------------------------------------------

        try:

            image_bytes = (
                image_file.file.read()
            )

        except Exception as exc:

            raise bad_request(
                f"Unable to read image: {exc}"
            )

        if not image_bytes:

            raise bad_request(
                "Uploaded image is empty."
            )

        # -----------------------------------------------------
        # Validate image format
        # -----------------------------------------------------

        content_type = (
            image_file.content_type
            or ""
        )

        allowed_types = {
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp",
        }

        if content_type not in allowed_types:

            raise bad_request(
                "Unsupported image format. "
                "Use JPEG, PNG, or WEBP."
            )

        # -----------------------------------------------------
        # Calculate blur score
        # -----------------------------------------------------
        #
        # Uses the same BlurService that is shared with
        # the AI pipeline.
        #
        # Lower score = blurrier image.
        #

        blur_score = (
            self.blur_service
            .calculate_blur_score(
                image_bytes
            )
        )

        image_quality = (
            self.blur_service
            .classify_quality(
                blur_score
            )
        )

        # -----------------------------------------------------
        # Upload image to Supabase Storage
        # -----------------------------------------------------

        image_url = (
            self.upload_to_storage(
                image_file=image_file,
                image_bytes=image_bytes,
            )
        )

        # -----------------------------------------------------
        # IMPORTANT:
        #
        # Do NOT classify the image here.
        #
        # The actual AI pipeline is executed later by:
        #
        # POST /ocr/process/{image_id}
        #
        # That pipeline performs:
        #
        # EasyOCR
        #     ↓
        # reading-region detection
        #     ↓
        # trained digit model
        #     ↓
        # blur/glare checks
        #     ↓
        # 9-class image classification
        #
        # Therefore classification is NULL at upload time.
        # -----------------------------------------------------

        classification = None

        # -----------------------------------------------------
        # Save image record
        # -----------------------------------------------------

        response = (
            self.db
            .table("meter_images")
            .insert(
                {
                    "reading_id":
                        request.reading_id,

                    "image_url":
                        image_url,

                    "blur_score":
                        blur_score,

                    "image_quality":
                        image_quality,

                    "ai_classification":
                        classification,
                }
            )
            .execute()
        )

        if not response.data:

            raise bad_request(
                "Unable to save image."
            )

        image = response.data[0]

        # -----------------------------------------------------
        # Return upload response
        # -----------------------------------------------------

        return ImageUploadResponse(

            image_id=str(
                image["id"]
            ),

            image_url=
                image["image_url"],

            blur_score=
                image["blur_score"],

            quality=
                image["image_quality"],

            classification=
                image.get(
                    "ai_classification"
                ),

        )

    # =========================================================
    # GET IMAGE
    # =========================================================

    def get_image(
        self,
        image_id: str,
    ) -> ImageResponse:

        response = (
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

        if not response.data:

            raise not_found(
                "Image not found."
            )

        return self._image_to_response(
            response.data[0]
        )

    # =========================================================
    # DELETE IMAGE
    # =========================================================

    def delete_image(
        self,
        image_id: str,
    ):

        # Check that image exists first.
        self.get_image(
            image_id
        )

        self.db \
            .table("meter_images") \
            .delete() \
            .eq(
                "id",
                image_id,
            ) \
            .execute()

        return {
            "message":
                "Image deleted successfully"
        }

    # =========================================================
    # UPLOAD TO SUPABASE STORAGE
    # =========================================================

    def upload_to_storage(
        self,
        image_file: UploadFile,
        image_bytes: bytes,
    ):

        filename = (
            f"{uuid4()}_{image_file.filename}"
        )

        bucket = "meter-images"

        try:

            result = (
                self.db
                .storage
                .from_(bucket)
                .upload(
                    filename,
                    image_bytes,
                    {
                        "content-type":
                            image_file.content_type
                        or "application/octet-stream"
                    },
                )
            )

        except Exception as exc:

            raise bad_request(
                f"Storage upload failed: {exc}"
            )

        if not result:

            raise bad_request(
                "Storage upload failed."
            )

        return (
            self.db
            .storage
            .from_(bucket)
            .get_public_url(
                filename
            )
        )

    # =========================================================
    # RESPONSE HELPER
    # =========================================================

    def _image_to_response(
        self,
        image: dict,
    ) -> ImageResponse:

        return ImageResponse(

            id=str(
                image["id"]
            ),

            reading_id=str(
                image["reading_id"]
            ),

            image_url=
                image["image_url"],

            quality=
                image["image_quality"],

            classification=
                image.get(
                    "ai_classification"
                ),

            blur_score=
                image.get(
                    "blur_score"
                ),

            uploaded_at=
                image["uploaded_at"],

        )