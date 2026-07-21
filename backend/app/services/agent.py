"""
Agent service for Sourcely.
LangChain tool-calling agent with knowledge base retrieval and web search.
"""

import json
from typing import Optional

from langchain_core.tools import tool
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_huggingface import HuggingFaceEndpoint
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings

from app.config import get_settings


AGENT_SYSTEM_PROMPT = """You are Sourcely, an intelligent knowledge assistant. You help users understand and explore their uploaded knowledge sources.

You have two tools available:
1. **knowledge_base_search**: Search the user's uploaded documents (PDFs, web pages, YouTube transcripts, etc.)
2. **web_search**: Search the web for current/external information

RULES:
- ALWAYS prefer knowledge_base_search FIRST when the question is about the uploaded sources.
- Only use web_search when:
  - The question needs information outside the uploaded sources
  - The user explicitly asks to compare with current information
  - knowledge_base_search returns no relevant results
- ALWAYS CITE your sources:
  - For knowledge base results: mention the source name, page number or timestamp
  - For web results: include the URL
- If NOTHING relevant is found in either tool, say so plainly.
- Be concise, accurate, and helpful.
- State which tools you used at the end of your response.

FORMAT YOUR RESPONSE:
1. Answer the question with citations inline
2. At the end, add: "Sources used: [knowledge_base / web_search / both]"
"""


def _get_embeddings() -> HuggingFaceEmbeddings:
    """Get the HuggingFace embeddings model."""
    settings = get_settings()
    return HuggingFaceEmbeddings(
        model_name=settings.embeddings_model_name,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


def _search_knowledge_base(knowledge_space_id: str, query: str, k: int = 4) -> list[dict]:
    """
    Search the Chroma vector store for relevant chunks.
    Returns a list of results with content and metadata.
    """
    settings = get_settings()
    embeddings = _get_embeddings()

    try:
        vectorstore = Chroma(
            collection_name=knowledge_space_id,
            embedding_function=embeddings,
            persist_directory=settings.chroma_persist_dir,
        )

        results = vectorstore.similarity_search_with_score(query, k=k)

        search_results = []
        for doc, score in results:
            search_results.append({
                "content": doc.page_content,
                "source_id": doc.metadata.get("source_id", "unknown"),
                "source_type": doc.metadata.get("source_type", "unknown"),
                "page": doc.metadata.get("page", "N/A"),
                "chunk_index": doc.metadata.get("chunk_index", 0),
                "relevance_score": float(score),
            })

        return search_results
    except Exception as e:
        print(f"Knowledge base search error: {e}")
        return []


def _search_web(query: str) -> list[dict]:
    """
    Search the web using DuckDuckGo.
    Returns a list of search results.
    """
    try:
        from duckduckgo_search import DDGS

        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=5))

        return [
            {
                "title": r.get("title", ""),
                "url": r.get("href", r.get("link", "")),
                "snippet": r.get("body", r.get("snippet", "")),
            }
            for r in results
        ]
    except Exception as e:
        print(f"Web search error: {e}")
        return []


def _get_source_names(knowledge_space_id: str, source_ids: list[str]) -> dict:
    """Look up source names from Supabase."""
    try:
        from app.database import get_supabase_client
        supabase = get_supabase_client()

        result = (
            supabase.table("sources")
            .select("id, original_name, type")
            .eq("knowledge_space_id", knowledge_space_id)
            .in_("id", source_ids)
            .execute()
        )

        return {s["id"]: s for s in result.data}
    except Exception:
        return {}


async def run_agent_chat(
    knowledge_space_id: str,
    user_message: str,
    chat_history: list[dict],
) -> dict:
    """
    Run the agentic chat pipeline.

    Instead of relying on tool-calling (which many free HF models handle poorly),
    we use a robust decide-then-execute approach:
    1. Search the knowledge base
    2. Optionally search the web if KB results are insufficient
    3. Generate an answer with citations using the LLM

    Args:
        knowledge_space_id: The knowledge space to search in.
        user_message: The user's question.
        chat_history: Previous messages in the conversation.

    Returns:
        Dict with 'answer', 'citations', and 'tools_used'.
    """
    settings = get_settings()

    # Step 1: Always search the knowledge base first
    kb_results = _search_knowledge_base(knowledge_space_id, user_message)

    tools_used = []
    citations = []
    context_parts = []

    if kb_results:
        tools_used.append("knowledge_base")
        # Get source names for better citations
        source_ids = list(set(r["source_id"] for r in kb_results))
        source_names = _get_source_names(knowledge_space_id, source_ids)

        context_parts.append("=== KNOWLEDGE BASE RESULTS ===")
        for i, result in enumerate(kb_results):
            source_info = source_names.get(result["source_id"], {})
            source_name = source_info.get("original_name", f"Source {result['source_id'][:8]}")
            page_info = f"Page {result['page']}" if result["page"] != "N/A" else ""

            context_parts.append(
                f"[Source: {source_name} {page_info}]\n{result['content']}\n"
            )

            citations.append({
                "source_id": result["source_id"],
                "source_name": source_name,
                "page": str(result["page"]),
                "snippet": result["content"][:200],
                "type": "knowledge_base",
            })

    # Step 2: Search the web if KB results are weak or empty
    needs_web = len(kb_results) == 0 or (
        kb_results and all(r["relevance_score"] > 1.5 for r in kb_results)
    )

    # Also search web if user explicitly asks for external info
    web_keywords = ["latest", "current", "recent", "news", "today", "compare", "vs",
                     "versus", "update", "2024", "2025", "2026"]
    if any(kw in user_message.lower() for kw in web_keywords):
        needs_web = True

    web_results = []
    if needs_web:
        web_results = _search_web(user_message)
        if web_results:
            tools_used.append("web_search")
            context_parts.append("\n=== WEB SEARCH RESULTS ===")
            for result in web_results:
                context_parts.append(
                    f"[Web: {result['title']}]\nURL: {result['url']}\n{result['snippet']}\n"
                )
                citations.append({
                    "url": result["url"],
                    "source_name": result["title"],
                    "snippet": result["snippet"][:200],
                    "type": "web",
                })

    # Step 3: Generate answer with LLM
    context = "\n".join(context_parts) if context_parts else "No relevant information found."

    # Build chat history string
    history_str = ""
    if chat_history:
        for msg in chat_history[-6:]:  # Last 6 messages for context
            role = "User" if msg["role"] == "user" else "Assistant"
            history_str += f"{role}: {msg['content']}\n"

    prompt = f"""{AGENT_SYSTEM_PROMPT}

CONTEXT FROM TOOLS:
{context}

{f"CHAT HISTORY:{chr(10)}{history_str}" if history_str else ""}

USER QUESTION: {user_message}

Provide a helpful, well-cited answer. Reference specific sources when making claims.
If using knowledge base results, cite the source name and page number.
If using web results, cite the URL.
At the end, state which tools were used.

ANSWER:"""

    try:
        llm = HuggingFaceEndpoint(
            repo_id=settings.llm_model_name,
            huggingfacehub_api_token=settings.huggingface_api_token,
            max_new_tokens=1024,
            temperature=0.4,
        )

        answer = llm.invoke(prompt)
        answer = answer.strip()

    except Exception as e:
        if context_parts:
            # Fallback: return the raw context if LLM fails
            answer = (
                f"I found relevant information but encountered an error generating a response.\n\n"
                f"Here are the relevant excerpts:\n\n"
                + "\n".join(context_parts)
                + f"\n\n(Error: {str(e)})"
            )
        else:
            answer = f"I wasn't able to find relevant information or generate a response. Error: {str(e)}"

    # Add tools_used tag if not already in the answer
    if not tools_used:
        tools_used = ["none"]

    return {
        "answer": answer,
        "citations": citations,
        "tools_used": tools_used,
    }
