"""
Chat router for Sourcely.
Handles agentic chat with citations and tool tracking.
"""

import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_user_id
from app.database import get_supabase_client
from app.models import ChatRequest, ChatResponse, MessageResponse
from app.services.agent import run_agent_chat

router = APIRouter(prefix="/knowledge-spaces", tags=["Chat"])


@router.post("/{space_id}/chat", response_model=ChatResponse)
async def chat_with_space(
    space_id: str,
    body: ChatRequest,
    user_id: str = Depends(get_user_id),
):
    """
    Send a message to the agentic chat for a knowledge space.
    The agent decides whether to search the knowledge base, the web, or both.
    Returns the answer with citations and tools_used.
    """
    supabase = get_supabase_client()

    # Verify user owns the knowledge space
    space = (
        supabase.table("knowledge_spaces")
        .select("id, name")
        .eq("id", space_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not space.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    # Get or create conversation
    conversation_id = body.conversation_id
    if not conversation_id:
        conversation_id = str(uuid.uuid4())
        supabase.table("conversations").insert(
            {
                "id": conversation_id,
                "knowledge_space_id": space_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        ).execute()

    # Save user message
    user_msg_id = str(uuid.uuid4())
    supabase.table("messages").insert(
        {
            "id": user_msg_id,
            "conversation_id": conversation_id,
            "role": "user",
            "content": body.message,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    ).execute()

    # Get chat history (last 10 messages for context)
    history_result = (
        supabase.table("messages")
        .select("role, content")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .limit(10)
        .execute()
    )
    chat_history = history_result.data[:-1]  # Exclude the message we just inserted

    # Run the agent
    try:
        agent_result = await run_agent_chat(
            knowledge_space_id=space_id,
            user_message=body.message,
            chat_history=chat_history,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Agent error: {str(e)}")

    # Save assistant message
    assistant_msg_id = str(uuid.uuid4())
    supabase.table("messages").insert(
        {
            "id": assistant_msg_id,
            "conversation_id": conversation_id,
            "role": "assistant",
            "content": agent_result["answer"],
            "citations": agent_result.get("citations", []),
            "tools_used": agent_result.get("tools_used", []),
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    ).execute()

    return ChatResponse(
        answer=agent_result["answer"],
        citations=agent_result.get("citations", []),
        tools_used=agent_result.get("tools_used", []),
        conversation_id=conversation_id,
        message_id=assistant_msg_id,
    )


@router.get("/{space_id}/messages", response_model=list[MessageResponse])
async def get_chat_history(
    space_id: str,
    user_id: str = Depends(get_user_id),
    conversation_id: str = None,
):
    """Get chat history for a knowledge space."""
    supabase = get_supabase_client()

    # Verify user owns the knowledge space
    space = (
        supabase.table("knowledge_spaces")
        .select("id")
        .eq("id", space_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not space.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    # Get conversations for this space
    if conversation_id:
        convos = [{"id": conversation_id}]
    else:
        convo_result = (
            supabase.table("conversations")
            .select("id")
            .eq("knowledge_space_id", space_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        convos = convo_result.data

    if not convos:
        return []

    # Get messages for the latest conversation
    messages_result = (
        supabase.table("messages")
        .select("*")
        .eq("conversation_id", convos[0]["id"])
        .order("created_at", desc=False)
        .execute()
    )

    return [
        MessageResponse(
            id=m["id"],
            conversation_id=m["conversation_id"],
            role=m["role"],
            content=m["content"],
            citations=m.get("citations"),
            tools_used=m.get("tools_used"),
            created_at=m["created_at"],
        )
        for m in messages_result.data
    ]
