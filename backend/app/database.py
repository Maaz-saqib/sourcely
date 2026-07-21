"""
Supabase client initialization for Sourcely backend.
Provides both a service-role client (for backend operations)
and a function to create user-scoped clients.
"""

from supabase import create_client, Client
from app.config import get_settings


def get_supabase_client() -> Client:
    """
    Returns a Supabase client with the service role key.
    Use this for backend operations (ingestion, status updates, etc.)
    """
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_role_key)


def get_supabase_anon_client() -> Client:
    """
    Returns a Supabase client with the anon key.
    Use this for operations that should respect RLS.
    """
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_anon_key)
