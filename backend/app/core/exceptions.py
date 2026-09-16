from fastapi import HTTPException, status

from app.models.common import ErrorResponse


def bad_request(
    message: str,
    errors: list[str] | None = None,
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=ErrorResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            message=message,
            errors=errors,
        ).model_dump(mode="json"),
    )


def unauthorized(
    message: str = "Unauthorized",
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=ErrorResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            message=message,
        ).model_dump(mode="json"),
    )


def forbidden(
    message: str = "Forbidden",
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=ErrorResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            message=message,
        ).model_dump(mode="json"),
    )


def not_found(
    message: str,
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=ErrorResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            message=message,
        ).model_dump(mode="json"),
    )


def conflict(
    message: str,
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=ErrorResponse(
            status_code=status.HTTP_409_CONFLICT,
            message=message,
        ).model_dump(mode="json"),
    )


def validation_error(
    message: str,
    errors: list[str] | None = None,
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail=ErrorResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            message=message,
            errors=errors,
        ).model_dump(mode="json"),
    )


def internal_server_error(
    message: str = "Internal Server Error",
) -> HTTPException:

    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=ErrorResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            message=message,
        ).model_dump(mode="json"),
    )