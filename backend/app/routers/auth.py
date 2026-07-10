from fastapi import APIRouter, HTTPException
from app.core.deps import get_supabase

router = APIRouter(
    prefix="/auth",
    tags=["Auth"]
)


@router.post("/login")
def login(email: str, password: str):

    db = get_supabase()

    try:
        response = db.auth.sign_in_with_password(
            {
                "email": email,
                "password": password
            }
        )

        return {
            "access_token": response.session.access_token,
            "user": response.user
        }

    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=str(e)
        )


@router.get("/me")
def me():
    return {
        "message": "Authenticated User Endpoint"
    }