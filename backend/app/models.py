"""
Pydantic request/response schemas for Sourcely API endpoints.
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ─── Knowledge Spaces ─────────────────────────────────────────────

class KnowledgeSpaceCreate(BaseModel):
    """Request body for creating a new knowledge space."""
    name: str = Field(..., min_length=1, max_length=200)


class KnowledgeSpaceResponse(BaseModel):
    """Response body for a knowledge space."""
    id: str
    user_id: str
    name: str
    created_at: str
    source_count: Optional[int] = 0


class KnowledgeSpaceDetail(KnowledgeSpaceResponse):
    """Detailed knowledge space response including sources."""
    sources: list["SourceResponse"] = []


# ─── Sources ──────────────────────────────────────────────────────

class SourceLinkCreate(BaseModel):
    """Request body for adding a URL or YouTube source."""
    knowledge_space_id: str
    source_type: str = Field(..., pattern="^(youtube|url)$")
    source_url: str
    original_name: Optional[str] = None


class QuizItem(BaseModel):
    """A single quiz question/answer pair."""
    question: str
    answer: str


class SourceResponse(BaseModel):
    """Response body for a source."""
    id: str
    knowledge_space_id: str
    type: str
    original_name: Optional[str] = None
    source_url: Optional[str] = None
    status: str
    error_message: Optional[str] = None
    chunk_count: Optional[int] = None
    summary: Optional[str] = None
    quiz: Optional[list[QuizItem]] = None
    created_at: str


class SourceStatusResponse(BaseModel):
    """Response body for source ingestion status polling."""
    id: str
    status: str
    error_message: Optional[str] = None
    chunk_count: Optional[int] = None
    summary: Optional[str] = None
    quiz: Optional[list[QuizItem]] = None


# ─── Chat ─────────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    """Request body for sending a chat message."""
    message: str = Field(..., min_length=1)
    conversation_id: Optional[str] = None


class Citation(BaseModel):
    """A citation reference in an assistant message."""
    source_id: Optional[str] = None
    source_name: Optional[str] = None
    page: Optional[str] = None
    timestamp: Optional[str] = None
    snippet: Optional[str] = None
    url: Optional[str] = None
    type: str = "knowledge_base"  # "knowledge_base" or "web"


class MessageResponse(BaseModel):
    """Response body for a chat message."""
    id: str
    conversation_id: str
    role: str
    content: str
    citations: Optional[list[Citation]] = None
    tools_used: Optional[list[str]] = None
    created_at: str


class ChatResponse(BaseModel):
    """Response body for a chat interaction."""
    answer: str
    citations: list[Citation] = []
    tools_used: list[str] = []
    conversation_id: str
    message_id: str
