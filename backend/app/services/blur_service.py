"""
app/services/blur_service.py

Image sharpness / blur detection service.

The threshold is shared with the ML pipeline in
app.ml.meter_core so the backend does not maintain
two different blur thresholds.
"""

import cv2
import numpy as np

from app.models.enums import ImageQuality
from app.ml.meter_core import BLUR_THRESHOLD


class BlurService:

    # =========================================================
    # CALCULATE BLUR SCORE
    # =========================================================

    def calculate_blur_score(
        self,
        image_bytes: bytes,
    ) -> float:

        np_image = np.frombuffer(
            image_bytes,
            np.uint8,
        )

        image = cv2.imdecode(
            np_image,
            cv2.IMREAD_GRAYSCALE,
        )

        if image is None:
            return 0.0

        # Variance of Laplacian.
        # Lower value = blurrier image.
        score = cv2.Laplacian(
            image,
            cv2.CV_64F,
        ).var()

        return float(score)

    # =========================================================
    # CHECK BLUR
    # =========================================================

    def is_blurry(
        self,
        score: float,
    ) -> bool:

        return score < BLUR_THRESHOLD

    # =========================================================
    # CLASSIFY IMAGE QUALITY
    # =========================================================

    def classify_quality(
        self,
        score: float,
    ) -> str:

        if self.is_blurry(score):
            return ImageQuality.BLUR.value

        return ImageQuality.OK.value