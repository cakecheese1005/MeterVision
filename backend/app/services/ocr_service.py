"""
OCR service — extracts meter reading digits from an image.
Uses EasyOCR with digit-only filtering.
Falls back to Tesseract if EasyOCR is unavailable.
"""
import re
import numpy as np
from typing import Optional, Tuple

# Lazy-load to avoid slow startup when not needed
_reader = None


def _get_reader():
    global _reader
    if _reader is None:
        try:
            import easyocr
            _reader = easyocr.Reader(["en"], gpu=False, verbose=False)
        except ImportError:
            _reader = "tesseract"
    return _reader


def extract_reading(image_bytes: bytes) -> Tuple[Optional[int], float]:
    """
    Returns (reading_value, confidence).
    reading_value is None if no digits could be extracted.
    confidence is 0.0–1.0.
    """
    reader = _get_reader()

    if reader == "tesseract":
        return _tesseract_extract(image_bytes)

    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    results = reader.readtext(arr, detail=1, paragraph=False)

    best_value = None
    best_conf = 0.0

    for (_bbox, text, conf) in results:
        # Strip non-digits and look for runs of 4–8 digits (typical meter reading)
        digits = re.sub(r"\D", "", text)
        if 4 <= len(digits) <= 8 and conf > best_conf:
            best_value = int(digits)
            best_conf = conf

    return best_value, best_conf


def _tesseract_extract(image_bytes: bytes) -> Tuple[Optional[int], float]:
    """Fallback using pytesseract."""
    try:
        import pytesseract
        import cv2
        import numpy as np

        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        # Preprocess: grayscale + threshold
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        config = "--oem 3 --psm 6 outputbase digits"
        raw = pytesseract.image_to_string(thresh, config=config)
        digits = re.sub(r"\D", "", raw)

        if 4 <= len(digits) <= 8:
            return int(digits), 0.60  # Fixed moderate confidence for Tesseract
    except Exception:
        pass
    return None, 0.0
