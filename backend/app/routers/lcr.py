from fastapi import APIRouter, Depends

from supabase import Client

from app.core.deps import get_supabase
from app.core.security import get_current_user

from app.models.lcr import (
    AssignLCR,
    LCRDecision,
    LCRCaseResponse,
)

from app.services.lcr_service import (
    LCRService,
)



router = APIRouter(
    prefix="/lcr",
    tags=["LCR"],
)



def get_lcr_service(
    db: Client = Depends(get_supabase),
):

    return LCRService(db)



# =========================================================
# CREATE CASE
# =========================================================

@router.post(
    "/",
    response_model=LCRCaseResponse,
)
def create_case(
    request: AssignLCR,
    current_user: dict = Depends(get_current_user),
    service: LCRService = Depends(
        get_lcr_service
    ),
):

    return service.assign_case(
        request
    )



# =========================================================
# GET ALL
# =========================================================

@router.get(
    "/",
    response_model=list[LCRCaseResponse],
)
def list_cases(
    current_user: dict = Depends(get_current_user),
    service: LCRService = Depends(
        get_lcr_service
    ),
):

    return service.list_cases()



# =========================================================
# GET ONE
# =========================================================

@router.get(
    "/{case_id}",
    response_model=LCRCaseResponse,
)
def get_case(
    case_id: str,
    current_user: dict = Depends(get_current_user),
    service: LCRService = Depends(
        get_lcr_service
    ),
):

    return service.get_case(
        case_id
    )



# =========================================================
# APPROVE
# =========================================================

@router.put(
    "/{case_id}/approve",
    response_model=LCRCaseResponse,
)
def approve_case(
    case_id: str,
    request: LCRDecision,
    current_user: dict = Depends(get_current_user),
    service: LCRService = Depends(
        get_lcr_service
    ),
):

    return service.approve_case(
        case_id,
        request,
    )



# =========================================================
# REJECT
# =========================================================

@router.put(
    "/{case_id}/reject",
    response_model=LCRCaseResponse,
)
def reject_case(
    case_id: str,
    request: LCRDecision,
    current_user: dict = Depends(get_current_user),
    service: LCRService = Depends(
        get_lcr_service
    ),
):

    return service.reject_case(
        case_id,
        request,
    )