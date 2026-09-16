"""
app/services/user_service.py
"""

from datetime import datetime, timezone

from supabase import Client

from app.core.exceptions import (
    bad_request,
    conflict,
    not_found,
)

from app.models.users import (
    UserCreate,
    UserUpdate,
    UserResponse,
)

from app.core.security import hash_password



class UserService:


    def __init__(
        self,
        db: Client,
    ):
        self.db = db



    # =========================================================
    # CREATE USER
    # =========================================================

    def create_user(
        self,
        request: UserCreate,
    ) -> UserResponse:


        existing = (
            self.db
            .table("users")
            .select("id")
            .eq(
                "email",
                str(request.email),
            )
            .limit(1)
            .execute()
        )


        if existing.data:

            raise conflict(
                "Email already exists."
            )



        response = (
            self.db
            .table("users")
            .insert(
                {

                    "name":
                    request.name,

                    "email":
                    str(request.email),

                    "password_hash":
                    hash_password(
                        request.password
                    ),

                    "role":
                    request.role.value,

                }
            )
            .execute()
        )


        if not response.data:

            raise bad_request(
                "Unable to create user."
            )


        return self._to_response(
            response.data[0]
        )



    # =========================================================
    # GET ALL USERS
    # =========================================================

    def get_users(
        self,
    ) -> list[UserResponse]:


        response = (
            self.db
            .table("users")
            .select("*")
            .order(
                "created_at",
                desc=True,
            )
            .execute()
        )


        return [

            self._to_response(row)

            for row in (
                response.data or []
            )

        ]



    # =========================================================
    # GET OFFICERS
    # =========================================================

    def get_officers(
        self,
    ) -> list[UserResponse]:


        response = (
            self.db
            .table("users")
            .select("*")
            .eq(
                "role",
                "officer",
            )
            .eq(
                "is_active",
                True,
            )
            .execute()
        )


        return [

            self._to_response(row)

            for row in (
                response.data or []
            )

        ]



    # =========================================================
    # GET ONE
    # =========================================================

    def get_user(
        self,
        user_id: str,
    ) -> UserResponse:


        response = (
            self.db
            .table("users")
            .select("*")
            .eq(
                "id",
                user_id,
            )
            .limit(1)
            .execute()
        )


        if not response.data:

            raise not_found(
                "User not found."
            )


        return self._to_response(
            response.data[0]
        )



    # =========================================================
    # UPDATE
    # =========================================================

    def update_user(
        self,
        user_id: str,
        request: UserUpdate,
    ) -> UserResponse:


        self.get_user(
            user_id
        )


        update_data = {}


        if request.name is not None:

            update_data["name"] = (
                request.name
            )


        if request.role is not None:

            update_data["role"] = (
                request.role.value
            )


        if not update_data:

            return self.get_user(
                user_id
            )


        update_data["updated_at"] = (
            datetime.now(
                timezone.utc
            ).isoformat()
        )


        response = (
            self.db
            .table("users")
            .update(update_data)
            .eq(
                "id",
                user_id,
            )
            .execute()
        )


        return self._to_response(
            response.data[0]
        )



    # =========================================================
    # DELETE / DEACTIVATE
    # =========================================================

    def deactivate_user(
        self,
        user_id: str,
    ):


        response = (
            self.db
            .table("users")
            .update(
                {
                    "is_active": False,

                    "updated_at":
                    datetime.now(
                        timezone.utc
                    ).isoformat(),
                }
            )
            .eq(
                "id",
                user_id,
            )
            .execute()
        )


        if not response.data:

            raise not_found(
                "User not found."
            )


        return {
            "message":
            "User deactivated successfully."
        }



    # =========================================================
    # HELPER
    # =========================================================

    def _to_response(
        self,
        user: dict,
    ) -> UserResponse:


        return UserResponse(

            id=str(
                user["id"]
            ),

            name=user["name"],

            email=user["email"],

            role=user["role"],

        )