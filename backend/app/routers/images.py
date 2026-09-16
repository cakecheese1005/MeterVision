"""
app/routers/images.py
"""

from fastapi import (
    APIRouter,
    Depends,
    UploadFile,
    File,
    Form,
)

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.image import (
    ImageUploadRequest,
    ImageUploadResponse,
    ImageResponse,
)

from app.services.image_service import (
    ImageService,
)


router = APIRouter(
    prefix="/images",
    tags=["Images"],
)


# =========================================================
# DEPENDENCY
# =========================================================

def get_image_service(
    db: Client = Depends(get_supabase),
) -> ImageService:

    return ImageService(
        db
    )


# =========================================================
# UPLOAD IMAGE
# =========================================================

@router.post(
    "/upload",
    response_model=ImageUploadResponse,
)
async def upload_image(

    reading_id: str = Form(...),

    latitude: float = Form(...),

    longitude: float = Form(...),

    file: UploadFile = File(...),

    current_user: dict = Depends(
        get_current_user
    ),

    service: ImageService = Depends(
        get_image_service
    ),

):

    request = ImageUploadRequest(

        reading_id=
            reading_id,

        latitude=
            latitude,

        longitude=
            longitude,

    )

    return service.upload_image(

        request=
            request,

        image_file=
            file,

    )


# =========================================================
# GET IMAGE
# =========================================================

@router.get(
    "/{image_id}",
    response_model=ImageResponse,
)
def get_image(

    image_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: ImageService = Depends(
        get_image_service
    ),

):

    return service.get_image(
        image_id
    )


# =========================================================
# DELETE IMAGE
# =========================================================

@router.delete(
    "/{image_id}",
)
def delete_image(

    image_id: str,

    current_user: dict = Depends(
        get_current_user
    ),

    service: ImageService = Depends(
        get_image_service
    ),

):

    return service.delete_image(
        image_id
    )