from supabase import Client, create_client

from app.core.config import settings


def create_supabase_client() -> Client:
    """
    Creates a singleton Supabase client.
    """

    return create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_KEY
    )


supabase: Client = create_supabase_client()


def get_supabase() -> Client:
    """
    FastAPI dependency.
    """

    return supabase