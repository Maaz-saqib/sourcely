"""
Sourcely Backend — FastAPI Application Entrypoint.
Multi-source RAG knowledge assistant with agentic chat.
"""
import os
# Bypass corrupted locally cached huggingface tokens (fixes embedding crash)
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import knowledge_spaces, sources, chat

# Create the FastAPI app
app = FastAPI(
    title="Sourcely API",
    description="Multi-source RAG knowledge assistant with agentic chat",
    version="1.0.0",
)

# Configure CORS
settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(knowledge_spaces.router, prefix="/api")
app.include_router(sources.router, prefix="/api")
app.include_router(chat.router, prefix="/api")


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "name": "Sourcely API",
        "version": "1.0.0",
        "status": "running",
    }


@app.get("/api/health")
async def health_check():
    """Detailed health check."""
    return {
        "status": "healthy",
        "services": {
            "api": "running",
            "llm_model": settings.llm_model_name,
            "embeddings_model": settings.embeddings_model_name,
        },
    }
