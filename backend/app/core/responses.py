from typing import Any

from app.models.common import (
    APIResponse,
    PaginationResponse,
    SuccessResponse,
)


def success(
    message: str = "Request completed successfully.",
    data: Any = None,
) -> APIResponse:

    return APIResponse(
        success=True,
        message=message,
        data=data,
    )


def created(
    message: str = "Resource created successfully.",
    data: Any = None,
) -> APIResponse:

    return APIResponse(
        success=True,
        message=message,
        data=data,
    )


def updated(
    message: str = "Resource updated successfully.",
    data: Any = None,
) -> APIResponse:

    return APIResponse(
        success=True,
        message=message,
        data=data,
    )


def accepted(
    message: str = "Request accepted.",
    data: Any = None,
) -> APIResponse:

    return APIResponse(
        success=True,
        message=message,
        data=data,
    )


def deleted(
    message: str = "Resource deleted successfully.",
) -> SuccessResponse:

    return SuccessResponse(
        success=True,
        message=message,
    )


def no_content(
    message: str = "No data available.",
) -> SuccessResponse:

    return SuccessResponse(
        success=True,
        message=message,
    )


def paginated(
    items: Any,
    pagination: PaginationResponse,
    message: str = "Data fetched successfully.",
) -> APIResponse:

    return APIResponse(
        success=True,
        message=message,
        data={
            "items": items,
            "pagination": pagination,
        },
    )