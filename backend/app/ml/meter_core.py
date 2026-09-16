"""Pure (non-Streamlit) meter-reading logic: OCR post-processing, region
detection, and rule-based classification heuristics.

Shared by maker_app.py (the interactive UI) and ml/*.py (dataset building,
training, evaluation) so both use exactly the same crop/heuristic logic —
no duplicated thresholds to drift out of sync.
"""

from __future__ import annotations

import io
import re

import cv2
import numpy as np
from PIL import Image

WATERMARK_BAND_FRACTION = 0.16  # bottom slice of the image the banner lives in

#  EasyOCR frequently misreads the banner's ':' as '.', so time uses [:.]
#  as the separator everywhere below rather than a literal colon.
FULL_WATERMARK_RE = re.compile(
    r"(\d{1,2}[-/][A-Za-z]{3}[-/]\d{4}[,\s]+\d{1,2}[:.]\d{2}[:.]\d{2})"
    r"[,\s]+(-?\d{1,3}\.\d{3,8})"
    r"[,\s]+(-?\d{1,3}\.\d{3,8})"
    r"[,\s]+(-?\d{1,3}\.\d{1,4})"
    r"[,\s]+(\d{6,})"
)
DATE_RE = re.compile(r"\d{1,2}[-/][A-Za-z]{3}[-/]\d{4}")
TIME_RE = re.compile(r"\d{1,2}[:.]\d{2}[:.]\d{2}")
DECIMAL_RE = re.compile(r"-?\d{1,3}\.\d{3,8}")
LONG_INT_RE = re.compile(r"\d{6,}")
KWH_RE = re.compile(r"k\s*w\s*h", re.IGNORECASE)
SNO_LABEL_RE = re.compile(r"s\.?\s*r?\s*no\.?|serial\s*no\.?", re.IGNORECASE)

# --- Confidence gates: below these, we say "not confidently readable"
# instead of showing a number, rather than presenting a low-confidence
# guess as if it were a fact. ---
MIN_READING_CONFIDENCE = 0.40
MIN_SERIAL_CONFIDENCE = 0.40

# --- Classification thresholds. All are best-effort rules built from
# signals available without a labeled training set (no ground truth for
# "this photo is blurry" / "this is a digital meter" was available to
# calibrate against) — treat them as a documented, adjustable starting
# point, not a validated model. Every raw signal is also shown in the UI
# so a wrong classification can be traced back to the number that drove it. ---
BLUR_THRESHOLD = 60.0  # Laplacian variance on the raw (pre-upscale) reading crop
GLARE_RATIO_THRESHOLD = 0.18  # fraction of near-blown-out pixels in that crop
LCD_COLOR_AREA_THRESHOLD = 0.015  # fraction of the photo covered by LCD-colored pixels
MIN_RELEVANT_DETECTIONS = 3  # OCR boxes outside the watermark band, below = "irrelevant"

CLASSIFICATIONS = {
    ("ok", "electro_mechanical"): (1, "Image OK — Electro Mechanical Meter"),
    ("blur", "electro_mechanical"): (2, "Blur Image — Electro Mechanical Meter"),
    ("blur", "digital"): (3, "Blur Image — Digital Meter"),
    ("mismatch", "electro_mechanical"): (4, "Reading Mismatch — Electro Mechanical Meter"),
    ("mismatch", "digital"): (5, "Reading Mismatch — Digital Meter"),
    ("reflection", "digital"): (6, "Reflection — Digital Meter"),
    ("irrelevant", "electro_mechanical"): (7, "Irrelevant Image — Electro Mechanical Meter"),
    ("irrelevant", "digital"): (8, "Irrelevant Image — Digital Meter"),
    ("ok", "digital"): (9, "Image OK — Digital Meter"),
}

CATEGORY_ICONS = {
    "ok": ":material/check_circle:",
    "blur": ":material/blur_on:",
    "reflection": ":material/wb_sunny:",
    "mismatch": ":material/rule:",
    "irrelevant": ":material/block:",
}


def bbox_metrics(bbox: list[list[float]]) -> tuple[float, float, float, float]:
    xs = [p[0] for p in bbox]
    ys = [p[1] for p in bbox]
    return min(xs), min(ys), max(xs), max(ys)


def ocr_raw_to_detections(raw: list) -> list[dict]:
    detections = []
    for bbox, text, confidence in raw:
        x0, y0, x1, y1 = bbox_metrics(bbox)
        detections.append(
            {
                "text": text,
                "confidence": confidence,
                "x0": x0,
                "y0": y0,
                "x1": x1,
                "y1": y1,
                "height": y1 - y0,
            }
        )
    return detections


def run_ocr(reader, image_bytes: bytes) -> list[dict]:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    raw = reader.readtext(np.array(image))
    return ocr_raw_to_detections(raw)


def digit_ratio(text: str) -> float:
    cleaned = text.strip()
    if not cleaned:
        return 0.0
    digits = sum(c.isdigit() for c in cleaned)
    return digits / len(cleaned)


def parse_watermark(detections: list[dict], image_height: int) -> dict:
    band_start = image_height * (1 - WATERMARK_BAND_FRACTION)
    band_boxes = [d for d in detections if d["y0"] >= band_start]
    band_boxes.sort(key=lambda d: d["x0"])
    band_text = ", ".join(d["text"] for d in band_boxes)

    match = FULL_WATERMARK_RE.search(band_text)
    if match:
        return {
            "timestamp": match.group(1),
            "latitude": match.group(2),
            "longitude": match.group(3),
            "constant_value": match.group(4),
            "consumer_or_meter_id": match.group(5),
            "raw_text": band_text,
            "parsed": True,
        }

    decimals = DECIMAL_RE.findall(band_text)
    date_match = DATE_RE.search(band_text)
    time_match = TIME_RE.search(band_text)
    id_candidates = LONG_INT_RE.findall(band_text)

    return {
        "timestamp": (
            f"{date_match.group(0)} {time_match.group(0)}"
            if date_match and time_match
            else None
        ),
        "latitude": decimals[0] if len(decimals) > 0 else None,
        "longitude": decimals[1] if len(decimals) > 1 else None,
        "constant_value": decimals[2] if len(decimals) > 2 else None,
        "consumer_or_meter_id": id_candidates[-1] if id_candidates else None,
        "raw_text": band_text,
        "parsed": False,
    }


def group_rows(detections: list[dict], gap_factor: float = 0.6) -> list[list[dict]]:
    """Group OCR boxes into text rows by vertical-center proximity."""
    by_y = sorted(detections, key=lambda d: (d["y0"] + d["y1"]) / 2)
    rows: list[list[dict]] = []
    for d in by_y:
        cy = (d["y0"] + d["y1"]) / 2
        placed = False
        for row in rows:
            last = row[-1]
            last_cy = (last["y0"] + last["y1"]) / 2
            if abs(cy - last_cy) < max(d["height"], last["height"]) * gap_factor:
                row.append(d)
                placed = True
                break
        if not placed:
            rows.append([d])
    return rows


def cluster_numeric_fragments(detections: list[dict]) -> list[dict]:
    """Merge nearby OCR boxes on the same row into single candidates.

    7-segment digit displays are frequently split by EasyOCR into two or
    three separate boxes (e.g. a large integer part plus a small decimal
    digit in a different color). This groups boxes that sit on the same
    text line and are horizontally close into one merged candidate so the
    scoring step sees the whole number, not a fragment of it.
    """
    rows = group_rows(detections)
    clusters = []
    for row in rows:
        row.sort(key=lambda d: d["x0"])
        current = [row[0]]
        for prev, curr in zip(row, row[1:]):
            gap = curr["x0"] - prev["x1"]
            avg_height = (prev["height"] + curr["height"]) / 2
            # Only extend a numeric run into another numeric-ish box —
            # otherwise an adjacent "kWh"/label box would drag a clean
            # digit cluster's combined digit-ratio below the keep threshold.
            both_numeric = digit_ratio(prev["text"]) >= 0.75 and digit_ratio(curr["text"]) >= 0.75
            if gap < avg_height * 1.3 and both_numeric:
                current.append(curr)
            else:
                clusters.append(current)
                current = [curr]
        clusters.append(current)

    merged = []
    for cluster in clusters:
        merged.append(
            {
                "text": "".join(box["text"] for box in cluster),
                "confidence": sum(b["confidence"] for b in cluster) / len(cluster),
                "x0": min(b["x0"] for b in cluster),
                "y0": min(b["y0"] for b in cluster),
                "x1": max(b["x1"] for b in cluster),
                "y1": max(b["y1"] for b in cluster),
                "height": max(b["height"] for b in cluster),
                "boxes": cluster,
            }
        )
    return merged


def guess_reading(detections: list[dict], image_height: int) -> tuple[dict | None, list[dict]]:
    band_start = image_height * (1 - WATERMARK_BAND_FRACTION)
    above_band = [d for d in detections if d["y0"] < band_start]
    merged = cluster_numeric_fragments(above_band)

    candidates = [
        c
        for c in merged
        if sum(ch.isdigit() for ch in c["text"]) >= 2
        and digit_ratio(c["text"]) >= 0.5
    ]
    if not candidates:
        return None, []

    kwh_boxes = [d for d in detections if KWH_RE.search(d["text"])]

    def score(c: dict) -> float:
        s = c["height"] * (0.5 + 0.5 * c["confidence"])
        for kwh in kwh_boxes:
            same_row = abs(
                ((c["y0"] + c["y1"]) / 2) - ((kwh["y0"] + kwh["y1"]) / 2)
            ) < (c["height"] * 1.5)
            if same_row:
                s *= 1.6
                break
        return s

    ranked = sorted(candidates, key=score, reverse=True)
    return ranked[0], ranked[1:5]


def padded_crop(
    image: Image.Image,
    bbox: tuple[float, float, float, float],
    pad_ratio_x: float = 0.6,
    pad_ratio_y: float = 0.35,
) -> tuple[Image.Image, float, float]:
    """Crop a padded box around a candidate at native resolution.

    Padding is wider than tall: horizontally it needs to reach a digit
    that didn't get merged into the coarse cluster (e.g. a decimal digit
    the strict merge threshold rejected), but vertically a generous pad
    risks pulling in an unrelated line of text above/below. Returns
    (crop, left, top) so callers can map coordinates back to the image.
    """
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    pad_x = w * pad_ratio_x + 15
    pad_y = h * pad_ratio_y + 8
    left = max(0, int(x0 - pad_x))
    top = max(0, int(y0 - pad_y))
    right = min(image.width, int(x1 + pad_x))
    bottom = min(image.height, int(y1 + pad_y))
    return image.crop((left, top, right, bottom)), left, top


def crop_region(
    image: Image.Image,
    bbox: tuple[float, float, float, float],
    pad_ratio_x: float = 0.6,
    pad_ratio_y: float = 0.35,
    target_height: int = 220,
) -> tuple[Image.Image, float, float, float]:
    """padded_crop(), then upscale for re-OCR. Returns (crop, scale, left, top)."""
    crop, left, top = padded_crop(image, bbox, pad_ratio_x, pad_ratio_y)
    if crop.height == 0 or crop.width == 0:
        return crop, 1.0, left, top
    scale = max(1.0, min(6.0, target_height / crop.height))
    if scale > 1.0:
        crop = crop.resize(
            (int(crop.width * scale), int(crop.height * scale)), Image.LANCZOS
        )
    return crop, scale, left, top


def compute_blur_score(crop: Image.Image) -> float:
    """Laplacian variance — a standard sharpness proxy. Lower = blurrier.
    Compute on a crop *before* any upscaling, since resizing changes the
    variance and would make scores incomparable across photos.
    """
    if crop.width == 0 or crop.height == 0:
        return 0.0
    gray = cv2.cvtColor(np.array(crop.convert("RGB")), cv2.COLOR_RGB2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def compute_glare_ratio(crop: Image.Image) -> float:
    """Fraction of near-blown-out (specular highlight) pixels in a crop."""
    if crop.width == 0 or crop.height == 0:
        return 0.0
    gray = cv2.cvtColor(np.array(crop.convert("RGB")), cv2.COLOR_RGB2GRAY)
    return float(np.count_nonzero(gray > 245)) / gray.size


def detect_meter_type(image: Image.Image) -> tuple[str, float]:
    """Digital meters in this dataset show a distinctly colored (green or
    blue-tinted) LCD/LED panel; electro-mechanical (dial/drum) meters
    don't. This is a coarse color-area proxy, not a trained classifier —
    it can misfire on an unusual meter design, so the area fraction is
    surfaced in the UI for a manual sanity check.
    """
    hsv = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2HSV)
    lower = np.array([35, 60, 40])
    upper = np.array([130, 255, 255])
    mask = cv2.inRange(hsv, lower, upper)
    area_fraction = float(np.count_nonzero(mask)) / mask.size
    meter_type = "digital" if area_fraction >= LCD_COLOR_AREA_THRESHOLD else "electro_mechanical"
    return meter_type, area_fraction


def find_serial_number(detections: list[dict], image_height: int, reading_boxes: list[dict]) -> dict | None:
    """Look for an "S.No." label and the numeric cluster nearest it.

    Falls back to the largest unlabeled numeric cluster on the nameplate
    (excluding the reading itself and the watermark) at reduced
    confidence if no label is found — that fallback is clearly marked as
    an unconfirmed guess wherever it's displayed, never presented as if
    it were read from a label.
    """
    band_start = image_height * (1 - WATERMARK_BAND_FRACTION)
    body = [d for d in detections if d["y0"] < band_start]
    label_boxes = [d for d in body if SNO_LABEL_RE.search(d["text"])]

    # Exclude '/' (dates like "01/2023") and require enough digits that
    # this couldn't plausibly be a rating or standard number picked up by
    # accident (IS/CM-L numbers, "10-60A", etc. tend to be shorter).
    numeric_clusters = [
        c
        for c in cluster_numeric_fragments(body)
        if sum(ch.isdigit() for ch in c["text"]) >= 5
        and digit_ratio(c["text"]) >= 0.7
        and "/" not in c["text"]
        and not re.search(r"\d{1,2}[.,]\d{2}[.,]\d{4}", c["text"])
    ]
    numeric_clusters = [
        c for c in numeric_clusters if not any(b in reading_boxes for b in c["boxes"])
    ]
    if not numeric_clusters:
        return None

    if label_boxes:
        label = label_boxes[0]
        label_cy = (label["y0"] + label["y1"]) / 2

        def distance(c: dict) -> float:
            ccy = (c["y0"] + c["y1"]) / 2
            dx = max(0.0, c["x0"] - label["x1"])
            return (dx**2 + (ccy - label_cy) ** 2) ** 0.5

        best = min(numeric_clusters, key=distance)
        return {"value": best["text"].strip(), "confidence": best["confidence"], "source": "labeled"}

    # No label found — only fall back within a serial-number-shaped digit
    # count (6-9, matching every real S.No. seen in this dataset). Outside
    # that range it's more likely a date, rating, or standard number, and
    # guessing one of those as a "serial number" would be exactly the kind
    # of made-up answer this function exists to avoid.
    plausible_length = [
        c for c in numeric_clusters if 6 <= sum(ch.isdigit() for ch in c["text"]) <= 9
    ]
    if not plausible_length:
        return None

    best = max(plausible_length, key=lambda c: c["confidence"])
    return {
        "value": best["text"].strip(),
        "confidence": best["confidence"] * 0.6,
        "source": "unlabeled_guess",
    }


def readings_agree(coarse: dict | None, rescan: dict | None) -> bool:
    """Two reads "agree" if they're identical, or one is a prefix/suffix of
    the other with at most a couple of extra characters (e.g. a dropped
    leading zero or trailing decimal digit). A same-length string with
    different digits, or one containing the other's digits buried in the
    middle of a much longer garbled string, does NOT count — those are
    exactly the false "agreement" that let bad guesses through unflagged.
    """
    if coarse is None or rescan is None:
        return False
    a = re.sub(r"[^0-9.]", "", coarse["text"])
    b = re.sub(r"[^0-9.]", "", rescan["text"])
    if not a or not b:
        return False
    if a == b:
        return True
    shorter, longer = sorted([a, b], key=len)
    if len(longer) - len(shorter) > 2:
        return False
    return longer.startswith(shorter) or longer.endswith(shorter)


def classify_image(
    meter_type: str,
    blur_score: float,
    glare_ratio: float,
    relevant_detection_count: int,
    coarse: dict | None,
    agrees: bool,
) -> dict:
    reasons = []

    if relevant_detection_count < MIN_RELEVANT_DETECTIONS and coarse is None:
        reasons.append(
            f"Only {relevant_detection_count} text region(s) found outside the "
            "watermark band — this doesn't look like a meter nameplate photo."
        )
        category = "irrelevant"
    elif meter_type == "digital" and glare_ratio >= GLARE_RATIO_THRESHOLD:
        reasons.append(
            f"{glare_ratio:.0%} of the display region is blown-out white — "
            "looks like glare/reflection off the display glass."
        )
        category = "reflection"
    elif blur_score < BLUR_THRESHOLD:
        reasons.append(
            f"Sharpness score {blur_score:.0f} is below the {BLUR_THRESHOLD:.0f} "
            "threshold — the display region looks blurred."
        )
        category = "blur"
    elif coarse is None:
        reasons.append("No confident digit cluster was found on the display.")
        category = "mismatch"
    elif not agrees:
        reasons.append(
            "The whole-image pass and the digit-focused rescan disagree on the "
            "reading — can't confirm the digits."
        )
        category = "mismatch"
    else:
        reasons.append("Reading extracted with good agreement; no blur or glare detected.")
        category = "ok"

    number, label = CLASSIFICATIONS[(category, meter_type)]
    return {"id": number, "label": label, "category": category, "reasons": reasons}


def apply_clahe(crop: Image.Image) -> Image.Image:
    gray = cv2.cvtColor(np.array(crop), cv2.COLOR_RGB2GRAY)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    return Image.fromarray(cv2.cvtColor(enhanced, cv2.COLOR_GRAY2RGB))


def image_to_bytes(image: Image.Image) -> bytes:
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    return buf.getvalue()


def rescan_digits(reader, crop_bytes: bytes) -> list[dict]:
    crop = Image.open(io.BytesIO(crop_bytes)).convert("RGB")
    raw = reader.readtext(np.array(crop), allowlist="0123456789.")
    return ocr_raw_to_detections(raw)


def merge_rescan_row(
    detections: list[dict], expected_cy: float, row_tolerance: float
) -> tuple[str, float] | None:
    """Pick the rescanned text row closest to where the original reading
    sat in the crop, so an unrelated line pulled in by padding is ignored.
    """
    if not detections:
        return None
    rows = group_rows(detections)

    def row_cy(row: list[dict]) -> float:
        return sum((d["y0"] + d["y1"]) / 2 for d in row) / len(row)

    best_row = min(rows, key=lambda r: abs(row_cy(r) - expected_cy))
    if abs(row_cy(best_row) - expected_cy) > row_tolerance:
        return None

    ordered = sorted(best_row, key=lambda d: d["x0"])
    text = "".join(d["text"] for d in ordered)
    if sum(ch.isdigit() for ch in text) < 2:
        return None
    confidence = sum(d["confidence"] for d in ordered) / len(ordered)
    return text, confidence


def rescan_candidate(reader, image: Image.Image, coarse: dict) -> dict | None:
    """Re-OCR a tight, upscaled, contrast-enhanced crop around the coarse
    best guess, restricted to digits only, and return it as a second,
    independent candidate (never silently replaces the coarse guess —
    neither pass is reliably better on every photo, so the caller shows
    both and lets you cross-check against the image).
    """
    bbox = (coarse["x0"], coarse["y0"], coarse["x1"], coarse["y1"])
    crop, scale, left, top = crop_region(image, bbox)
    if crop.width == 0 or crop.height == 0:
        return None

    original_cy = (coarse["y0"] + coarse["y1"]) / 2
    expected_cy = (original_cy - top) * scale
    row_tolerance = max((coarse["y1"] - coarse["y0"]) * scale, 20)

    variants = [crop, apply_clahe(crop)]
    best_variant = None
    for variant in variants:
        result = merge_rescan_row(
            rescan_digits(reader, image_to_bytes(variant)), expected_cy, row_tolerance
        )
        if result is None:
            continue
        text, confidence = result
        if best_variant is None or confidence > best_variant["confidence"]:
            best_variant = {"text": text, "confidence": confidence}
    return best_variant
