from datetime import datetime, timedelta, timezone

import jwt
from supabase import Client

from app.core.config import settings
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
)
from app.core.exceptions import (
    bad_request,
    unauthorized,
    conflict,
    not_found,
)
from app.models.auth import (
    LoginRequest,
    LoginData,
    RegisterUserRequest,
    RegisterUserData,
    UpdateProfileRequest,
    UserProfile,
    ChangePasswordRequest,
    RefreshSessionRequest,
    RefreshSessionData,
)
from app.models.enums import UserRole


class AuthService:

    def __init__(self, db: Client):
        self.db = db

    # =========================================================
    # Authentication
    # =========================================================

    def login(
        self,
        request: LoginRequest,
    ) -> LoginData:
        """
        Authenticate a user using the application's users table
        and return access + refresh JWTs.
        """

        user = self._get_user_by_email(str(request.email))

        if not user:
            raise unauthorized("Invalid email or password.")

        if not user.get("is_active", False):
            raise unauthorized("User account is inactive.")

        password_hash = user.get("password_hash")

        if not password_hash:
            raise unauthorized("Invalid email or password.")

        print("DEBUG password type:", type(request.password))
        print("DEBUG password length:", len(request.password))
        print("DEBUG password repr:", repr(request.password))
        print("DEBUG hash type:", type(password_hash))
        print("DEBUG hash length:", len(password_hash))
        print("DEBUG hash prefix:", password_hash[:7])
        if not self._verify_password(
            request.password,
            password_hash,
        ):
            raise unauthorized("Invalid email or password.")

        # Update last login
        self.db.table("users").update(
            {
                "last_login": datetime.now(timezone.utc).isoformat()
            }
        ).eq(
            "id",
            user["id"]
        ).execute()

        access_token = self._generate_access_token(user)
        refresh_token = self._generate_refresh_token(user)

        return LoginData(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            user_id=str(user["id"]),
            name=user["name"],
            email=user["email"],
            role=UserRole(user["role"]),
        )

    # =========================================================
    # Logout
    # =========================================================

    def logout(
        self,
        user_id: str,
    ) -> None:
        """
        JWT authentication is stateless.

        The client should delete its access/refresh tokens.
        There is currently no token/session blacklist table in
        the database, so the backend cannot revoke an already
        issued JWT immediately.
        """

        return None

    # =========================================================
    # Refresh Session
    # =========================================================

    def refresh_session(
        self,
        request: RefreshSessionRequest,
    ) -> RefreshSessionData:

        try:
            payload = jwt.decode(
                request.refresh_token,
                settings.JWT_SECRET,
                algorithms=[settings.JWT_ALGORITHM],
            )

        except jwt.ExpiredSignatureError:
            raise unauthorized("Refresh token has expired.")

        except jwt.InvalidTokenError:
            raise unauthorized("Invalid refresh token.")

        if payload.get("type") != "refresh":
            raise unauthorized("Invalid refresh token.")

        user_id = payload.get("sub")

        if not user_id:
            raise unauthorized("Invalid refresh token.")

        user = self._get_user_by_id(user_id)

        if not user:
            raise unauthorized("User no longer exists.")

        if not user.get("is_active", False):
            raise unauthorized("User account is inactive.")

        access_token = self._generate_access_token(user)
        refresh_token = self._generate_refresh_token(user)

        return RefreshSessionData(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
        )

    # =========================================================
    # Registration
    # =========================================================

    def register_user(
        self,
        request: RegisterUserRequest,
    ) -> RegisterUserData:

        existing_user = self._get_user_by_email(
            str(request.email)
        )

        if existing_user:
            raise conflict(
                "A user with this email already exists."
            )

        password_hash = self._hash_password(
            request.password
        )

        response = self.db.table("users").insert(
            {
                "name": request.name,
                "email": str(request.email),
                "password_hash": password_hash,
                "role": request.role.value,
                "is_active": True,
            }
        ).execute()

        if not response.data:
            raise bad_request(
                "Unable to create user."
            )

        user = response.data[0]

        return RegisterUserData(
            id=str(user["id"]),
            name=user["name"],
            email=user["email"],
            role=UserRole(user["role"]),
            created_at=user["created_at"],
        )

    # =========================================================
    # Profile
    # =========================================================

    def get_profile(
        self,
        user_id: str,
    ) -> UserProfile:

        user = self._get_user_by_id(user_id)

        if not user:
            raise not_found("User not found.")

        return UserProfile(
            id=str(user["id"]),
            name=user["name"],
            email=user["email"],
            role=UserRole(user["role"]),
            phone_number=user.get("phone_number"),
            last_login=user.get("last_login"),
            created_at=user["created_at"],
        )

    def update_profile(
        self,
        user_id: str,
        request: UpdateProfileRequest,
    ) -> UserProfile:

        user = self._get_user_by_id(user_id)

        if not user:
            raise not_found("User not found.")

        update_data = {}

        if request.name is not None:
            update_data["name"] = request.name

        if request.phone_number is not None:
            update_data["phone_number"] = request.phone_number

        if not update_data:
            return self.get_profile(user_id)

        update_data["updated_at"] = (
            datetime.now(timezone.utc).isoformat()
        )

        response = self.db.table("users").update(
            update_data
        ).eq(
            "id",
            user_id
        ).execute()

        if not response.data:
            raise bad_request(
                "Unable to update profile."
            )

        updated_user = response.data[0]

        return UserProfile(
            id=str(updated_user["id"]),
            name=updated_user["name"],
            email=updated_user["email"],
            role=UserRole(updated_user["role"]),
            phone_number=updated_user.get("phone_number"),
            last_login=updated_user.get("last_login"),
            created_at=updated_user["created_at"],
        )

    # =========================================================
    # Password
    # =========================================================

    def change_password(
        self,
        user_id: str,
        request: ChangePasswordRequest,
    ) -> None:

        user = self._get_user_by_id(user_id)

        if not user:
            raise not_found("User not found.")

        new_password_hash = self._hash_password(
            request.new_password
        )

        response = self.db.table("users").update(
            {
                "password_hash": new_password_hash,
                "updated_at": datetime.now(
                    timezone.utc
                ).isoformat(),
            }
        ).eq(
            "id",
            user_id
        ).execute()

        if not response.data:
            raise bad_request(
                "Unable to change password."
            )

    def forgot_password(
        self,
        email: str,
    ) -> None:
        """
        Generates a reset token.

        Email delivery is intentionally not implemented yet because
        there is currently no email service in the backend.
        """

        user = self._get_user_by_email(email)

        # Do not reveal whether an email exists.
        if not user:
            return None

        reset_token = self._generate_reset_token(user)

        # TODO:
        # Send reset_token through the email service.
        #
        # We intentionally do not return the token from the API.

        return None

    def reset_password(
        self,
        token: str,
        new_password: str,
    ) -> None:

        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET,
                algorithms=[settings.JWT_ALGORITHM],
            )

        except jwt.ExpiredSignatureError:
            raise unauthorized("Reset token has expired.")

        except jwt.InvalidTokenError:
            raise unauthorized("Invalid reset token.")

        if payload.get("type") != "password_reset":
            raise unauthorized("Invalid reset token.")

        user_id = payload.get("sub")

        if not user_id:
            raise unauthorized("Invalid reset token.")

        user = self._get_user_by_id(user_id)

        if not user:
            raise not_found("User not found.")

        new_password_hash = self._hash_password(
            new_password
        )

        response = self.db.table("users").update(
            {
                "password_hash": new_password_hash,
                "updated_at": datetime.now(
                    timezone.utc
                ).isoformat(),
            }
        ).eq(
            "id",
            user_id
        ).execute()

        if not response.data:
            raise bad_request(
                "Unable to reset password."
            )

    # =========================================================
    # Internal Helpers
    # =========================================================

    def _get_user_by_email(
        self,
        email: str,
    ) -> dict | None:

        response = self.db.table("users").select(
            "*"
        ).eq(
            "email",
            email
        ).limit(1).execute()

        if not response.data:
            return None

        return response.data[0]

    def _get_user_by_id(
        self,
        user_id: str,
    ) -> dict | None:

        response = self.db.table("users").select(
            "*"
        ).eq(
            "id",
            user_id
        ).limit(1).execute()

        if not response.data:
            return None

        return response.data[0]

    # =========================================================
    # Password Helpers
    # =========================================================

    def _hash_password(
        self,
        password: str,
    ) -> str:

        return hash_password(password)

    def _verify_password(
        self,
        plain_password: str,
        hashed_password: str,
    ) -> bool:

        return verify_password(
            plain_password,
            hashed_password,
        )

    # =========================================================
    # JWT Helpers
    # =========================================================

    def _generate_access_token(
        self,
        user: dict,
    ) -> str:

        return create_access_token(
            user_id=str(user["id"]),
            email=user["email"],
            role=user["role"],
        )

    def _generate_refresh_token(
        self,
        user: dict,
    ) -> str:

        now = datetime.now(timezone.utc)

        payload = {
            "sub": str(user["id"]),
            "email": user["email"],
            "role": user["role"],
            "iat": now,
            "exp": now + timedelta(
                days=settings.REFRESH_TOKEN_EXPIRE_DAYS
            ),
            "type": "refresh",
        }

        return jwt.encode(
            payload,
            settings.JWT_SECRET,
            algorithm=settings.JWT_ALGORITHM,
        )

    def _generate_reset_token(
        self,
        user: dict,
    ) -> str:

        now = datetime.now(timezone.utc)

        payload = {
            "sub": str(user["id"]),
            "iat": now,
            "exp": now + timedelta(
                minutes=30
            ),
            "type": "password_reset",
        }

        return jwt.encode(
            payload,
            settings.JWT_SECRET,
            algorithm=settings.JWT_ALGORITHM,
        )