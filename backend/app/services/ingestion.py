"""
Ingestion pipeline for Sourcely.
Handles document loading, chunking, embedding, and storage in Chroma.
Triggers auto-summary and quiz generation after ingestion.
"""

import os
import tempfile
import traceback
from typing import Optional

import chromadb
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_chroma import Chroma

from app.config import get_settings
from app.database import get_supabase_client
from app.services.summary_quiz import generate_summary_and_quiz


def _get_embeddings() -> HuggingFaceEmbeddings:
    """Get the HuggingFace embeddings model."""
    settings = get_settings()
    return HuggingFaceEmbeddings(
        model_name=settings.embeddings_model_name,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


def _get_chroma_collection(knowledge_space_id: str) -> Chroma:
    """Get or create a Chroma collection for a knowledge space."""
    settings = get_settings()
    embeddings = _get_embeddings()

    return Chroma(
        collection_name=knowledge_space_id,
        embedding_function=embeddings,
        persist_directory=settings.chroma_persist_dir,
    )


def _load_pdf(file_path: str):
    """Load a PDF file using PyPDFLoader."""
    from langchain_community.document_loaders import PyPDFLoader

    loader = PyPDFLoader(file_path)
    return loader.load()


def _load_docx(file_path: str):
    """Load a DOCX file using Docx2txtLoader."""
    from langchain_community.document_loaders import Docx2txtLoader

    loader = Docx2txtLoader(file_path)
    return loader.load()


def _load_youtube(url: str):
    """Load YouTube transcript using YoutubeLoader."""
    from langchain_community.document_loaders import YoutubeLoader

    # add_video_info=False bypasses pytube which is currently broken on YouTube
    loader = YoutubeLoader.from_youtube_url(url, add_video_info=False)
    return loader.load()


def _load_url(url: str):
    """Load web page content using WebBaseLoader."""
    from langchain_community.document_loaders import WebBaseLoader

    loader = WebBaseLoader(url)
    return loader.load()


def _download_from_supabase(storage_path: str) -> str:
    """Download a file from Supabase Storage to a temp directory."""
    supabase = get_supabase_client()
    file_data = supabase.storage.from_("source-files").download(storage_path)

    # Save to temp file
    ext = storage_path.rsplit(".", 1)[-1] if "." in storage_path else "bin"
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}")
    temp_file.write(file_data)
    temp_file.close()
    return temp_file.name


def run_ingestion_pipeline(
    source_id: str,
    knowledge_space_id: str,
    source_type: str,
    source_url: Optional[str] = None,
    storage_path: Optional[str] = None,
):
    """
    Main ingestion pipeline — runs as a background task.

    1. Load the document using the appropriate LangChain loader.
    2. Split into chunks with RecursiveCharacterTextSplitter.
    3. Embed and store in Chroma.
    4. Generate auto-summary and quiz.
    5. Update the source status in Supabase.
    """
    supabase = get_supabase_client()
    temp_file_path = None

    try:
        # Step 1: Load documents
        if source_type == "pdf":
            temp_file_path = _download_from_supabase(storage_path)
            documents = _load_pdf(temp_file_path)
        elif source_type == "docx":
            temp_file_path = _download_from_supabase(storage_path)
            documents = _load_docx(temp_file_path)
        elif source_type == "youtube":
            documents = _load_youtube(source_url)
        elif source_type == "url":
            documents = _load_url(source_url)
        else:
            # Fallback for all other generic file types (txt, csv, json, md, etc)
            from langchain_community.document_loaders import TextLoader
            temp_file_path = _download_from_supabase(storage_path)
            try:
                loader = TextLoader(temp_file_path, autodetect_encoding=True)
                documents = loader.load()
            except Exception as e:
                raise ValueError(f"Failed to extract text from {source_type} file: {str(e)}")

        if not documents:
            raise ValueError("No content could be extracted from the source")

        # Collect full text for summary/quiz generation
        full_text = "\n\n".join([doc.page_content for doc in documents])

        # Add source metadata to all documents
        for i, doc in enumerate(documents):
            doc.metadata["source_id"] = source_id
            doc.metadata["source_type"] = source_type
            doc.metadata["chunk_index"] = i
            # Preserve page number if available (PDFs)
            if "page" not in doc.metadata:
                doc.metadata["page"] = str(i)

        # Step 2: Split into chunks
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=150,
            length_function=len,
            separators=["\n\n", "\n", ". ", " ", ""],
        )
        chunks = text_splitter.split_documents(documents)

        # Update chunk metadata with proper chunk_index after splitting
        for i, chunk in enumerate(chunks):
            chunk.metadata["chunk_index"] = i

        # Step 3: Embed and store in Chroma
        vectorstore = _get_chroma_collection(knowledge_space_id)
        vectorstore.add_documents(
            documents=chunks,
            ids=[f"{source_id}_chunk_{i}" for i in range(len(chunks))],
        )

        # Step 4: Generate summary and quiz
        summary_quiz = generate_summary_and_quiz(full_text)

        # Step 5: Update source status to ready
        supabase.table("sources").update(
            {
                "status": "ready",
                "chunk_count": len(chunks),
                "summary": summary_quiz.get("summary", ""),
                "quiz": summary_quiz.get("quiz", []),
            }
        ).eq("id", source_id).execute()

    except Exception as e:
        # Update source status to failed
        error_msg = f"{str(e)}\n{traceback.format_exc()}"
        supabase.table("sources").update(
            {
                "status": "failed",
                "error_message": error_msg[:2000],  # Truncate long errors
            }
        ).eq("id", source_id).execute()

    finally:
        # Clean up temp file
        if temp_file_path and os.path.exists(temp_file_path):
            os.unlink(temp_file_path)


def delete_source_data(source_id: str, knowledge_space_id: str, chunk_count: int, storage_path: Optional[str] = None):
    """
    Deletes the source chunks from ChromaDB and the raw file from Supabase Storage.
    """
    supabase = get_supabase_client()
    try:
        if storage_path:
            supabase.storage.from_("source-files").remove([storage_path])
        
        if chunk_count and chunk_count > 0:
            vectorstore = _get_chroma_collection(knowledge_space_id)
            ids_to_delete = [f"{source_id}_chunk_{i}" for i in range(chunk_count)]
            vectorstore.delete(ids=ids_to_delete)
    except Exception as e:
        print(f"Error deleting source data: {e}")

