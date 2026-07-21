"""
Sourcely Backend Configuration.
Loads settings from environment variables via pydantic-settings.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_jwt_secret: str

    # Hugging Face
    huggingface_api_token: str

    # Chroma
    chroma_persist_dir: str = "./chroma_data"

    # LLM (Primary - Groq)
    groq_api_key: str = ""
    groq_model_name: str = "llama-3.3-70b-versatile"

    # LLM (Fallback - Gemini)
    gemini_api_key: str = ""
    gemini_model_name: str = "gemini-2.0-flash"

    # Embeddings
    embeddings_model_name: str = "sentence-transformers/all-MiniLM-L6-v2"

    # CORS
    cors_origins: list[str] = ["*"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()
