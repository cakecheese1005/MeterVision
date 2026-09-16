from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.ocr import (
    OCRResultCreate,
    OCRVerification,
    OCRResultResponse,
)

from app.services.ocr_service import (
    OCRService,
)


router = APIRouter(
    prefix="/ocr",
    tags=["OCR"],
)


# =========================================================
# DEPENDENCY
# =========================================================

def get_ocr_service(
    db: Client = Depends(get_supabase),
) -> OCRService:

    return OCRService(db)


# =========================================================
# PROCESS IMAGE WITH AI
# =========================================================

@router.post(
    "/process/{image_id}",
    response_model=OCRResultResponse,
)
def process_image(

    image_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: OCRService = Depends(
        get_ocr_service
    ),

):

    return service.process_image(
        image_id
    )


# =========================================================
# SAVE OCR RESULT MANUALLY
# =========================================================

@router.post(
    "/save",
    response_model=OCRResultResponse,
)
def save_result(

    request: OCRResultCreate,

    current_user: dict = Depends(
        get_current_user
    ),

    service: OCRService = Depends(
        get_ocr_service
    ),

):

    return service.save_result(
        request
    )


# =========================================================
# VERIFY / CORRECT OCR
# =========================================================

@router.put(
    "/{ocr_id}/verify",
    response_model=OCRResultResponse,
)
def verify_result(

    ocr_id: str,

    request: OCRVerification,

    current_user: dict = Depends(
        get_current_user
    ),

    service: OCRService = Depends(
        get_ocr_service
    ),

):

    return service.verify_result(
        ocr_id,
        request,
    )


# =========================================================
# GET OCR RESULT BY READING
# =========================================================

@router.get(
    "/{reading_id}",
    response_model=OCRResultResponse,
)
def get_result(

    reading_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: OCRService = Depends(
        get_ocr_service
    ),

):

    return service.get_result(
        reading_id
    )