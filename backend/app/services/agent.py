"""
Agent service for Sourcely.
LangChain tool-calling agent with knowledge base retrieval and web search.
"""

import json
from typing import Optional, List
from pydantic import BaseModel, Field

from langchain_core.prompts import ChatPromptTemplate
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings

from app.config import get_settings

AGENT_SYSTEM_PROMPT = """You are Sourcely, an intelligent knowledge assistant. You help users understand and explore their uploaded knowledge sources.

You have two tools available:
1. **knowledge_base**: Search the user's uploaded documents (PDFs, web pages, YouTube transcripts, etc.)
2. **web_search**: Search the web for current/external information

RULES:
- ALWAYS prefer knowledge_base FIRST when the question is about the uploaded sources.
- Only use web_search when:
  - The question needs information outside the uploaded sources
  - The user explicitly asks to compare with current information
  - knowledge_base returns no relevant results
- ALWAYS CITE your sources:
  - For knowledge base results: mention the source name, page number or timestamp
  - For web results: include the URL
- If NOTHING relevant is found in either tool, say so plainly.
- Be concise, accurate, and helpful.

FORMAT YOUR RESPONSE:
1. Answer the question with citations inline
2. Structure your output exactly according to the schema provided.
"""

class Citation(BaseModel):
    source_id: Optional[str] = Field(None, description="The ID of the source if from knowledge base")
    source_name: str = Field(..., description="The name of the source or web page title")
    page: Optional[str] = Field(None, description="Page number or timestamp if applicable")
    snippet: str = Field(..., description="A short snippet of the text used")
    type: str = Field(..., description="'knowledge_base' or 'web'")

class AgentResponse(BaseModel):
    answer: str = Field(..., description="The complete answer to the user's question, containing inline citations.")
    citations: List[Citation] = Field(default_factory=list, description="List of all sources used to generate the answer.")
    tools_used: List[str] = Field(default_factory=lambda: ["none"], description="List of tools used (e.g. 'knowledge_base', 'web_search').")

def _get_llm():
    settings = get_settings()
    
    if settings.groq_api_key:
        from langchain_groq import ChatGroq
        try:
            return ChatGroq(
                model=settings.groq_model_name,
                api_key=settings.groq_api_key,
                temperature=0.2
            )
        except Exception as e:
            print(f"Failed to init Groq: {e}")
            
    if settings.gemini_api_key:
        from langchain_google_genai import ChatGoogleGenerativeAI
        try:
            return ChatGoogleGenerativeAI(
                model=settings.gemini_model_name,
                google_api_key=settings.gemini_api_key,
                temperature=0.2
            )
        except Exception as e:
            print(f"Failed to init Gemini: {e}")
            
    raise ValueError("No valid LLM API key configured. Set GROQ_API_KEY or GEMINI_API_KEY.")

def _get_embeddings() -> HuggingFaceEmbeddings:
    settings = get_settings()
    return HuggingFaceEmbeddings(
        model_name=settings.embeddings_model_name,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )

def _search_knowledge_base(knowledge_space_id: str, query: str, k: int = 4) -> list[dict]:
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
    kb_results = _search_knowledge_base(knowledge_space_id, user_message)
    tools_used = []
    context_parts = []
    
    # Store minimal pre-formatted citations to help the LLM generate the structured output
    pre_citations = []

    if kb_results:
        tools_used.append("knowledge_base")
        source_ids = list(set(r["source_id"] for r in kb_results))
        source_names = _get_source_names(knowledge_space_id, source_ids)

        context_parts.append("=== KNOWLEDGE BASE RESULTS ===")
        for result in kb_results:
            source_info = source_names.get(result["source_id"], {})
            source_name = source_info.get("original_name", f"Source {result['source_id'][:8]}")
            page_info = f"Page {result['page']}" if result["page"] != "N/A" else ""
            context_parts.append(f"[Source: {source_name} {page_info}]\n{result['content']}\n")
            pre_citations.append({
                "source_id": result["source_id"],
                "source_name": source_name,
                "page": str(result["page"]),
                "snippet": result["content"][:200],
                "type": "knowledge_base",
            })

    needs_web = len(kb_results) == 0 or (kb_results and all(r["relevance_score"] > 1.5 for r in kb_results))
    web_keywords = ["latest", "current", "recent", "news", "today", "compare", "vs", "versus", "update", "2024", "2025", "2026"]
    if any(kw in user_message.lower() for kw in web_keywords):
        needs_web = True

    if needs_web:
        web_results = _search_web(user_message)
        if web_results:
            tools_used.append("web_search")
            context_parts.append("\n=== WEB SEARCH RESULTS ===")
            for result in web_results:
                context_parts.append(f"[Web: {result['title']}]\nURL: {result['url']}\n{result['snippet']}\n")
                pre_citations.append({
                    "url": result["url"],
                    "source_name": result["title"],
                    "snippet": result["snippet"][:200],
                    "type": "web",
                })

    context = "\n".join(context_parts) if context_parts else "No relevant information found."
    history_str = ""
    if chat_history:
        for msg in chat_history[-6:]:
            role = "User" if msg["role"] == "user" else "Assistant"
            history_str += f"{role}: {msg['content']}\n"

    prompt_template = ChatPromptTemplate.from_messages([
        ("system", AGENT_SYSTEM_PROMPT),
        ("user", "CONTEXT FROM TOOLS:\n{context}\n\nCHAT HISTORY:\n{history_str}\n\nUSER QUESTION: {user_message}")
    ])

    try:
        llm = _get_llm()
        structured_llm = llm.with_structured_output(AgentResponse)
        prompt = prompt_template.invoke({
            "context": context,
            "history_str": history_str,
            "user_message": user_message
        })
        
        result: AgentResponse = structured_llm.invoke(prompt)
        
        return {
            "answer": result.answer,
            "citations": [c.model_dump() for c in result.citations],
            "tools_used": result.tools_used if result.tools_used else tools_used,
        }
    except Exception as e:
        print(f"LLM Generation Error: {e}")
        # Fallback if LLM structured output fails
        if not tools_used:
            tools_used = ["none"]
            
        answer = f"I wasn't able to find relevant information or generate a response. Error: {str(e)}"
        if context_parts:
            answer = f"I found relevant information but encountered an error generating a response.\n\nHere are the relevant excerpts:\n\n" + "\n".join(context_parts)
            
        return {
            "answer": answer,
            "citations": pre_citations,
            "tools_used": tools_used,
        }
