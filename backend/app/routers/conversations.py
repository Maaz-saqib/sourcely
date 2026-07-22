"""
Conversations and Chat router for Sourcely.
Handles creating/managing conversations, sending chat messages, and getting history.
"""

import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Body

from app.auth import get_user_id
from app.database import get_supabase_client
from app.models import (
    ConversationCreate, 
    ConversationUpdate, 
    ConversationResponse,
    ChatRequest, 
    ChatResponse, 
    MessageResponse
)
from app.services.agent import run_agent_chat
from app.exceptions import ResourceNotFoundError, ExternalServiceError, DatabaseError

router = APIRouter(tags=["Conversations"])


# ─── Conversation Management ──────────────────────────────────────

@router.post("/knowledge-spaces/{space_id}/conversations", response_model=ConversationResponse)
async def create_conversation(
    space_id: str,
    body: ConversationCreate,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()
    
    # Verify ownership
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Knowledge space not found")

    conversation_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    
    data = {
        "id": conversation_id,
        "knowledge_space_id": space_id,
        "name": body.name,
        "created_at": now,
        "updated_at": now,
    }
    
    result = supabase.table("conversations").insert(data).execute()
    return result.data[0]


@router.get("/knowledge-spaces/{space_id}/conversations", response_model=list[ConversationResponse])
async def list_conversations(
    space_id: str,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()
    
    # Verify ownership
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Knowledge space not found")

    result = supabase.table("conversations").select("*").eq("knowledge_space_id", space_id).order("updated_at", desc=True).execute()
    return result.data


@router.patch("/conversations/{conversation_id}", response_model=ConversationResponse)
async def update_conversation(
    conversation_id: str,
    body: ConversationUpdate,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()
    
    # Verify ownership via join or just checking if conversation exists and space is owned by user
    convo = supabase.table("conversations").select("knowledge_space_id").eq("id", conversation_id).execute()
    if not convo.data:
        raise ResourceNotFoundError("Conversation not found")
        
    space_id = convo.data[0]["knowledge_space_id"]
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Conversation not found")

    now = datetime.now(timezone.utc).isoformat()
    result = supabase.table("conversations").update({"name": body.name, "updated_at": now}).eq("id", conversation_id).execute()
    return result.data[0]


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()
    
    convo = supabase.table("conversations").select("knowledge_space_id").eq("id", conversation_id).execute()
    if not convo.data:
        raise ResourceNotFoundError("Conversation not found")
        
    space_id = convo.data[0]["knowledge_space_id"]
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Conversation not found")

    supabase.table("conversations").delete().eq("id", conversation_id).execute()
    return {"status": "success"}


# ─── Chat and Messages ────────────────────────────────────────────

@router.post("/conversations/{conversation_id}/chat", response_model=ChatResponse)
async def chat_in_conversation(
    conversation_id: str,
    body: ChatRequest,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()

    convo = supabase.table("conversations").select("knowledge_space_id").eq("id", conversation_id).execute()
    if not convo.data:
        raise ResourceNotFoundError("Conversation not found")
        
    space_id = convo.data[0]["knowledge_space_id"]
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Conversation not found")

    now = datetime.now(timezone.utc).isoformat()

    # Save user message
    user_msg_id = str(uuid.uuid4())
    supabase.table("messages").insert(
        {
            "id": user_msg_id,
            "conversation_id": conversation_id,
            "role": "user",
            "content": body.message,
            "created_at": now,
        }
    ).execute()

    # Update conversation timestamp
    supabase.table("conversations").update({"updated_at": now}).eq("id", conversation_id).execute()

    # Get chat history
    history_result = (
        supabase.table("messages")
        .select("role, content")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .limit(10)
        .execute()
    )
    chat_history = history_result.data[:-1]

    # Run the agent
    try:
        agent_result = await run_agent_chat(
            knowledge_space_id=space_id,
            user_message=body.message,
            chat_history=chat_history,
            mentioned_source_ids=body.mentioned_source_ids,
        )
    except Exception as e:
        raise ExternalServiceError(f"Agent error: {str(e)}")

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


@router.get("/conversations/{conversation_id}/messages", response_model=list[MessageResponse])
async def get_messages(
    conversation_id: str,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()

    convo = supabase.table("conversations").select("knowledge_space_id").eq("id", conversation_id).execute()
    if not convo.data:
        raise ResourceNotFoundError("Conversation not found")
        
    space_id = convo.data[0]["knowledge_space_id"]
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Conversation not found")

    messages_result = (
        supabase.table("messages")
        .select("*")
        .eq("conversation_id", conversation_id)
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

import io
from fastapi.responses import JSONResponse
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet

@router.post("/messages/{message_id}/export-pdf")
async def export_message_pdf(
    message_id: str,
    user_id: str = Depends(get_user_id),
):
    supabase = get_supabase_client()
    
    # 1. Fetch message and verify ownership
    msg = supabase.table("messages").select("*, conversations!inner(knowledge_space_id)").eq("id", message_id).execute()
    if not msg.data:
        raise ResourceNotFoundError("Message not found")
        
    space_id = msg.data[0]["conversations"]["knowledge_space_id"]
    space = supabase.table("knowledge_spaces").select("id").eq("id", space_id).eq("user_id", user_id).execute()
    if not space.data:
        raise ResourceNotFoundError("Message not found")

    message_data = msg.data[0]
    
    # 2. Generate PDF in memory
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Add title
    story.append(Paragraph("Sourcely Chat Export", styles['Title']))
    story.append(Spacer(1, 12))
    
    # Add content
    for line in message_data["content"].split('\n'):
        if line.strip():
            story.append(Paragraph(line, styles['Normal']))
            story.append(Spacer(1, 6))
            
    # Add citations
    citations = message_data.get("citations")
    if citations:
        story.append(Spacer(1, 12))
        story.append(Paragraph("Sources", styles['Heading2']))
        for cite in citations:
            source_name = cite.get("source_name", "Unknown Source")
            url = cite.get("url", "")
            page = cite.get("page", "")
            
            ref = f"<b>{source_name}</b>"
            if page and page != "N/A" and page != "None":
                ref += f" (Page {page})"
            if url:
                ref += f" - <i>{url}</i>"
                
            story.append(Paragraph(ref, styles['Normal']))
            story.append(Spacer(1, 4))
            
    doc.build(story)
    
    # 3. Upload to Supabase Storage
    buffer.seek(0)
    pdf_bytes = buffer.read()
    file_name = f"exports/message_{message_id}.pdf"
    
    try:
        supabase.storage.from_("source-files").upload(
            file_name,
            pdf_bytes,
            {"content-type": "application/pdf"}
        )
    except Exception as e:
        # Ignore if file already exists
        if "Duplicate" not in str(e):
            print(f"Upload error: {e}")
            
    # 4. Get signed URL
    signed_url = supabase.storage.from_("source-files").create_signed_url(file_name, 3600)
    
    return {"url": signed_url["signedURL"]}
