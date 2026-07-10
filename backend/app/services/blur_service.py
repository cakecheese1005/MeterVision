"""
Blur detection using OpenCV Laplacian variance method.
Higher variance = sharper image.
Below BLUR_THRESHOLD => image is blurred, officer must recapture.
"""
import cv2
import numpy as np
from app.core.config import settings


def check(image_bytes: bytes) -> tuple[float, bool]:
    """
    Returns (blur_score: float, is_blurred: bool).
    blur_score is the Laplacian variance — higher is sharper.
    """
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError("Could not decode image — check file format")
    score = float(cv2.Laplacian(img, cv2.CV_64F).var())
    return score, score < settings.BLUR_THRESHOLD


def check_from_path(path: str) -> tuple[float, bool]:
    img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError(f"Could not read image at {path}")
    score = float(cv2.Laplacian(img, cv2.CV_64F).var())
    return score, score < settings.BLUR_THRESHOLD
