"""
Sources router for Sourcely.
Handles file upload, link submission, and ingestion status polling.
"""

import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks

from app.auth import get_user_id
from app.database import get_supabase_client
from app.models import SourceLinkCreate, SourceResponse, SourceStatusResponse
from app.services.ingestion import run_ingestion_pipeline, delete_source_data

router = APIRouter(prefix="/sources", tags=["Sources"])


@router.post("", response_model=SourceResponse)
async def create_source_from_link(
    body: SourceLinkCreate,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_user_id),
):
    """
    Create a new source from a URL or YouTube link.
    Kicks off background ingestion.
    """
    supabase = get_supabase_client()

    # Verify user owns the knowledge space
    space = (
        supabase.table("knowledge_spaces")
        .select("id")
        .eq("id", body.knowledge_space_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not space.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    source_id = str(uuid.uuid4())
    original_name = body.original_name or body.source_url

    data = {
        "id": source_id,
        "knowledge_space_id": body.knowledge_space_id,
        "type": body.source_type,
        "original_name": original_name,
        "source_url": body.source_url,
        "status": "processing",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    result = supabase.table("sources").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create source")

    # Kick off ingestion in the background
    background_tasks.add_task(
        run_ingestion_pipeline,
        source_id=source_id,
        knowledge_space_id=body.knowledge_space_id,
        source_type=body.source_type,
        source_url=body.source_url,
    )

    row = result.data[0]
    return SourceResponse(
        id=row["id"],
        knowledge_space_id=row["knowledge_space_id"],
        type=row["type"],
        original_name=row.get("original_name"),
        source_url=row.get("source_url"),
        status=row["status"],
        created_at=row["created_at"],
    )


@router.post("/upload", response_model=SourceResponse)
async def create_source_from_file(
    knowledge_space_id: str = Form(...),
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    user_id: str = Depends(get_user_id),
):
    """
    Upload a PDF or DOCX file as a source.
    Saves to Supabase Storage and kicks off background ingestion.
    """
    supabase = get_supabase_client()

    # Verify user owns the knowledge space
    space = (
        supabase.table("knowledge_spaces")
        .select("id")
        .eq("id", knowledge_space_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not space.data:
        raise HTTPException(status_code=404, detail="Knowledge space not found")

    # Determine source type from file extension
    filename = file.filename or "unknown"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if ext == "pdf":
        source_type = "pdf"
    elif ext in ("docx", "doc"):
        source_type = "docx"
    else:
        # Accept any other file extension generically
        source_type = ext if ext else "unknown"

    source_id = str(uuid.uuid4())

    # Upload file to Supabase Storage
    file_content = await file.read()
    storage_path = f"sources/{knowledge_space_id}/{source_id}/{filename}"

    try:
        supabase.storage.from_("source-files").upload(
            path=storage_path,
            file=file_content,
            file_options={"content-type": file.content_type or "application/octet-stream"},
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to upload file: {str(e)}")

    data = {
        "id": source_id,
        "knowledge_space_id": knowledge_space_id,
        "type": source_type,
        "original_name": filename,
        "storage_path": storage_path,
        "status": "processing",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    result = supabase.table("sources").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create source")

    # Kick off ingestion in the background
    background_tasks.add_task(
        run_ingestion_pipeline,
        source_id=source_id,
        knowledge_space_id=knowledge_space_id,
        source_type=source_type,
        storage_path=storage_path,
    )

    row = result.data[0]
    return SourceResponse(
        id=row["id"],
        knowledge_space_id=row["knowledge_space_id"],
        type=row["type"],
        original_name=row.get("original_name"),
        status=row["status"],
        created_at=row["created_at"],
    )


@router.get("/{source_id}/status", response_model=SourceStatusResponse)
async def get_source_status(
    source_id: str,
    user_id: str = Depends(get_user_id),
):
    """Poll the ingestion status of a source."""
    supabase = get_supabase_client()

    result = (
        supabase.table("sources")
        .select("*, knowledge_spaces!inner(user_id)")
        .eq("id", source_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Source not found")

    row = result.data[0]

    # Verify ownership through the knowledge space
    if row.get("knowledge_spaces", {}).get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="Source not found")

    return SourceStatusResponse(
        id=row["id"],
        status=row["status"],
        error_message=row.get("error_message"),
        chunk_count=row.get("chunk_count"),
        summary=row.get("summary"),
        quiz=row.get("quiz"),
    )

@router.delete("/{source_id}")
async def delete_source(
    source_id: str,
    user_id: str = Depends(get_user_id),
):
    """Delete a source from Supabase and Chroma."""
    supabase = get_supabase_client()

    # Verify ownership and get source details
    result = (
        supabase.table("sources")
        .select("*, knowledge_spaces!inner(user_id)")
        .eq("id", source_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Source not found")

    row = result.data[0]
    if row.get("knowledge_spaces", {}).get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="Source not found")

    # Delete data (Chroma & Storage)
    delete_source_data(
        source_id=source_id,
        knowledge_space_id=row["knowledge_space_id"],
        chunk_count=row.get("chunk_count", 0),
        storage_path=row.get("storage_path"),
    )

    # Delete from Supabase DB
    supabase.table("sources").delete().eq("id", source_id).execute()

    return {"status": "deleted"}
