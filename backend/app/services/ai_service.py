"""
app/services/ai_service.py

AI inference service for PSPCL meter images.

Pipeline:

Image
  ↓
EasyOCR detection
  ↓
Reading candidate detection
  ↓
Digit-focused OCR rescan
  ↓
Trained MobileNet digit model
  ↓
Blur / glare / meter-type checks
  ↓
9-class image classification
  ↓
Final reading + confidence
"""

from __future__ import annotations

import io
from functools import lru_cache

import easyocr
from PIL import Image

from app.ml.digit_model import (
    MIN_DIGIT_CONFIDENCE,
    DigitReaderModel,
    load_digit_model,
)

from app.ml.meter_core import (
    MIN_READING_CONFIDENCE,
    WATERMARK_BAND_FRACTION,

    classify_image,
    compute_blur_score,
    compute_glare_ratio,

    detect_meter_type,
    find_serial_number,

    guess_reading,
    padded_crop,

    parse_watermark,
    readings_agree,

    rescan_candidate,
    run_ocr,
)


# =========================================================
# CONSTANTS
# =========================================================

MODEL_VERSION = "digit-reader-v1"


# =========================================================
# LOAD EASY OCR ONCE
# =========================================================

@lru_cache(maxsize=1)
def get_ocr_reader() -> easyocr.Reader:

    return easyocr.Reader(
        ["en"],
        gpu=False,
    )


# =========================================================
# LOAD DIGIT MODEL ONCE
# =========================================================

@lru_cache(maxsize=1)
def get_digit_reader() -> DigitReaderModel | None:

    return load_digit_model()


# =========================================================
# SERVICE
# =========================================================

class AIService:

    def __init__(self):

        self.ocr_reader = (
            get_ocr_reader()
        )

        self.digit_model = (
            get_digit_reader()
        )

    # =====================================================
    # PROCESS IMAGE
    # =====================================================

    def process_image(
        self,
        image_bytes: bytes,
    ) -> dict:

        # -------------------------------------------------
        # Decode image
        # -------------------------------------------------

        try:

            image = (
                Image.open(
                    io.BytesIO(image_bytes)
                )
                .convert("RGB")
            )

        except Exception as exc:

            raise ValueError(
                f"Invalid image: {exc}"
            )

        # -------------------------------------------------
        # EASY OCR
        # -------------------------------------------------

        detections = run_ocr(
            self.ocr_reader,
            image_bytes,
        )

        # -------------------------------------------------
        # READING REGION
        # -------------------------------------------------

        coarse, alternates = (
            guess_reading(
                detections,
                image.height,
            )
        )

        # -------------------------------------------------
        # SECOND OCR PASS
        # -------------------------------------------------

        rescan = None

        if coarse is not None:

            rescan = rescan_candidate(
                self.ocr_reader,
                image,
                coarse,
            )

        agrees = readings_agree(
            coarse,
            rescan,
        )

        # -------------------------------------------------
        # TRAINED DIGIT MODEL
        # -------------------------------------------------

        model_result = None

        if (
            self.digit_model is not None
            and coarse is not None
        ):

            bbox = (
                coarse["x0"],
                coarse["y0"],
                coarse["x1"],
                coarse["y1"],
            )

            model_result = (
                self.digit_model.predict_region(
                    image,
                    bbox,
                )
            )

        # -------------------------------------------------
        # MODEL CONFIDENCE
        # -------------------------------------------------

        model_readable = (

            model_result is not None

            and model_result["confidence"]
                >= MIN_DIGIT_CONFIDENCE
        )

        # -------------------------------------------------
        # HEURISTIC OCR CONFIDENCE
        # -------------------------------------------------

        heuristic_readable = (

            coarse is not None

            and (
                (
                    rescan is not None

                    # A high-confidence rescan is only
                    # meaningful as corroboration if it
                    # actually agrees with the coarse
                    # read — a confident but unrelated
                    # rescan (e.g. it picked up padding
                    # text) must not validate coarse's
                    # text.
                    and agrees

                    and rescan["confidence"]
                        >= MIN_READING_CONFIDENCE
                )

                or (

                    rescan is None

                    and coarse["confidence"]
                        >= (
                            MIN_READING_CONFIDENCE
                            + 0.15
                        )
                )
            )
        )

        # -------------------------------------------------
        # FINAL READING
        # -------------------------------------------------

        if model_readable:

            reading = (
                model_result["text"]
            )

            reading_confidence = (
                model_result["confidence"]
            )

            reading_source = (
                "trained_model"
            )

        elif heuristic_readable:

            reading = (
                coarse["text"]
                .strip()
            )

            reading_confidence = (

                rescan["confidence"]

                if rescan is not None

                else coarse["confidence"]
            )

            reading_source = (
                "ocr_heuristic"
            )

        else:

            reading = None

            reading_confidence = None

            reading_source = None

        # -------------------------------------------------
        # METER TYPE
        # -------------------------------------------------

        meter_type, lcd_area_fraction = (
            detect_meter_type(
                image
            )
        )

        # -------------------------------------------------
        # BLUR / GLARE CROP
        # -------------------------------------------------

        if coarse is not None:

            blur_crop, _, _ = (
                padded_crop(
                    image,
                    (
                        coarse["x0"],
                        coarse["y0"],
                        coarse["x1"],
                        coarse["y1"],
                    ),
                )
            )

        else:

            blur_crop = image

        blur_score = (
            compute_blur_score(
                blur_crop
            )
        )

        glare_ratio = (
            compute_glare_ratio(
                blur_crop
            )
        )

        # -------------------------------------------------
        # IMAGE CLASSIFICATION
        # -------------------------------------------------

        relevant_detection_count = sum(

            1

            for detection in detections

            if detection["y0"]
            < (
                image.height
                * (
                    1
                    - WATERMARK_BAND_FRACTION
                )
            )
        )

        classification = classify_image(

            meter_type,

            blur_score,

            glare_ratio,

            relevant_detection_count,

            coarse,

            agrees,
        )

        # -------------------------------------------------
        # WATERMARK
        # -------------------------------------------------

        watermark = parse_watermark(
            detections,
            image.height,
        )

        # -------------------------------------------------
        # SERIAL NUMBER
        # -------------------------------------------------

        reading_boxes = (
            coarse["boxes"]
            if coarse is not None
            else []
        )

        serial = find_serial_number(

            detections,

            image.height,

            reading_boxes,
        )

        serial_readable = (

            serial is not None

            and serial["confidence"]
                >= 0.40
        )

        # -------------------------------------------------
        # FINAL RESULT
        # -------------------------------------------------

        return {

            # ---------------------------------------------
            # READING
            # ---------------------------------------------

            "reading":
                reading,

            "reading_confidence":
                (
                    round(
                        reading_confidence,
                        4,
                    )
                    if reading_confidence
                    is not None
                    else None
                ),

            "reading_source":
                reading_source,

            # ---------------------------------------------
            # MODEL
            # ---------------------------------------------

            "model_readable":
                model_readable,

            "model_result":
                model_result,

            "model_version":
                MODEL_VERSION,

            # ---------------------------------------------
            # OCR
            # ---------------------------------------------

            "coarse_reading":
                (
                    coarse["text"]
                    if coarse
                    else None
                ),

            "coarse_confidence":
                (
                    coarse["confidence"]
                    if coarse
                    else None
                ),

            "rescan_reading":
                (
                    rescan["text"]
                    if rescan
                    else None
                ),

            "rescan_confidence":
                (
                    rescan["confidence"]
                    if rescan
                    else None
                ),

            "ocr_agrees":
                agrees,

            # ---------------------------------------------
            # CLASSIFICATION
            # ---------------------------------------------

            "classification_id":
                classification["id"],

            "classification":
                classification["label"],

            "classification_category":
                classification["category"],

            "classification_reasons":
                classification["reasons"],

            # ---------------------------------------------
            # METER
            # ---------------------------------------------

            "meter_type":
                meter_type,

            "lcd_area_fraction":
                round(
                    lcd_area_fraction,
                    4,
                ),

            # ---------------------------------------------
            # IMAGE QUALITY
            # ---------------------------------------------

            "blur_score":
                round(
                    blur_score,
                    2,
                ),

            "glare_ratio":
                round(
                    glare_ratio,
                    4,
                ),

            # ---------------------------------------------
            # SERIAL
            # ---------------------------------------------

            "serial_number":
                (
                    serial["value"]
                    if serial_readable
                    else None
                ),

            "serial_confidence":
                (
                    round(
                        serial["confidence"],
                        4,
                    )
                    if serial_readable
                    else None
                ),

            # ---------------------------------------------
            # WATERMARK
            # ---------------------------------------------

            "timestamp":
                watermark["timestamp"],

            "latitude":
                watermark["latitude"],

            "longitude":
                watermark["longitude"],

            "consumer_or_meter_id":
                watermark[
                    "consumer_or_meter_id"
                ],
        }