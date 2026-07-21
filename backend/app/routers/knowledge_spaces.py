"""
Knowledge Spaces router for Sourcely.
Handles CRUD operations for knowledge spaces.
"""

import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_user_id
from app.database import get_supabase_client
from app.models import (
    KnowledgeSpaceCreate,
    KnowledgeSpaceResponse,
    KnowledgeSpaceDetail,
    SourceResponse,
)

router = APIRouter(prefix="/knowledge-spaces", tags=["Knowledge Spaces"])


@router.post("", response_model=KnowledgeSpaceResponse)
async def create_knowledge_space(
    body: KnowledgeSpaceCreate,
    user_id: str = Depends(get_user_id),
):
    """Create a new knowledge space for the authenticated user."""
    supabase = get_supabase_client()
    space_id = str(uuid.uuid4())

    data = {
        "id": space_id,
        "user_id": user_id,
        "name": body.name,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    result = supabase.table("knowledge_spaces").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create knowledge space")

    row = result.data[0]
    return KnowledgeSpaceResponse(
        id=row["id"],
        user_id=row["user_id"],
        name=row["name"],
        created_at=row["created_at"],
        source_count=0,
    )


@router.get("", response_model=list[KnowledgeSpaceResponse])
async def list_knowledge_spaces(user_id: str = Depends(get_user_id)):
    """List all knowledge spaces for the authenticated user."""
    supabase = get_supabase_client()

    result = (
        supabase.table("knowledge_spaces")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )

    spaces = []
    for row in result.data:
        # Count sources for each space
        source_count_result = (
            supabase.table("sources")
            .select("id", count="exact")
            .eq("knowledge_space_id", row["id"])
            .execute()
        )
        count = source_count_result.count if source_count_result.count else 0

        spaces.append(
            KnowledgeSpaceResponse(
                id=row["id"],
                user_id=row["user_id"],
                name=row["name"],
                created_at=row["created_at"],
                source_count=count,
            )
        )

    return spaces


@router.get("/{space_id}", response_model=KnowledgeSpaceDetail)
async def get_knowledge_space(
    space_id: str,
    user_id: str = Depends(get_user_id),
):
    """Get a knowledge space with all its sources."""
    supabase = get_supabase_client()

    # Get the space
    result = (
        supabase.table("knowledge_spaces")
        .select("*")
        .eq("id", space_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    row = result.data[0]

    # Get sources for this space
    sources_result = (
        supabase.table("sources")
        .select("*")
        .eq("knowledge_space_id", space_id)
        .order("created_at", desc=True)
        .execute()
    )

    sources = []
    for s in sources_result.data:
        sources.append(
            SourceResponse(
                id=s["id"],
                knowledge_space_id=s["knowledge_space_id"],
                type=s["type"],
                original_name=s.get("original_name"),
                source_url=s.get("source_url"),
                status=s["status"],
                error_message=s.get("error_message"),
                chunk_count=s.get("chunk_count"),
                summary=s.get("summary"),
                quiz=s.get("quiz"),
                created_at=s["created_at"],
            )
        )

    return KnowledgeSpaceDetail(
        id=row["id"],
        user_id=row["user_id"],
        name=row["name"],
        created_at=row["created_at"],
        source_count=len(sources),
        sources=sources,
    )


@router.delete("/{space_id}")
async def delete_knowledge_space(
    space_id: str,
    user_id: str = Depends(get_user_id),
):
    """Delete a knowledge space and all its sources."""
    supabase = get_supabase_client()

    # Verify ownership
    result = (
        supabase.table("knowledge_spaces")
        .select("id")
        .eq("id", space_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    # Delete sources first (cascade)
    supabase.table("sources").delete().eq("knowledge_space_id", space_id).execute()

    # Delete conversations and messages
    convos = (
        supabase.table("conversations")
        .select("id")
        .eq("knowledge_space_id", space_id)
        .execute()
    )
    for convo in convos.data:
        supabase.table("messages").delete().eq("conversation_id", convo["id"]).execute()
    supabase.table("conversations").delete().eq(
        "knowledge_space_id", space_id
    ).execute()

    # Delete the space
    supabase.table("knowledge_spaces").delete().eq("id", space_id).execute()

    # Clean up Chroma collection
    try:
        import chromadb
        from app.config import get_settings

        settings = get_settings()
        chroma_client = chromadb.PersistentClient(path=settings.chroma_persist_dir)
        chroma_client.delete_collection(name=space_id)
    except Exception:
        pass  # Collection might not exist

    return {"status": "deleted"}
