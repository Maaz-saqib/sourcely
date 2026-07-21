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

AGENT_SYSTEM_PROMPT = """You are Sourcely, an intelligent, articulate, creative, and engaging AI knowledge assistant. You help users explore their uploaded knowledge sources and engage in insightful conversations.

RULES & BEHAVIOR:
1. **Uploaded Knowledge Sources**: When relevant document context from the Knowledge Base is provided, prioritize it, answer accurately, and cite the source name and page/timestamp.
2. **Web Search & General Knowledge**: If the user's question asks for external info or isn't covered in the uploaded documents, use Web Search or draw upon your extensive general knowledge.
3. **Conversational & Casual Interaction**: For greetings ("hi", "hello"), casual chat, math, coding, or creative prompts, respond naturally, warmly, and helpfully using your core AI capabilities. Never refuse to answer or throw an error just because no documents match!
4. **Creativity & Format**: Be engaging, articulate, structured, and insightful! Use Markdown formatting (bolding, lists, code blocks, headers) to make your answers visually clear and delightful to read.
"""

class Citation(BaseModel):
    source_id: Optional[str] = Field(None, description="The ID of the source if from knowledge base")
    source_name: str = Field(..., description="The name of the source or web page title")
    page: Optional[str] = Field(None, description="Page number or timestamp if applicable")
    snippet: str = Field(..., description="A short snippet of the text used")
    type: str = Field(..., description="'knowledge_base' or 'web'")

class AgentResponse(BaseModel):
    answer: str = Field(..., description="The complete, articulate answer to the user's question, containing inline citations if applicable.")
    citations: List[Citation] = Field(default_factory=list, description="List of all sources used to generate the answer.")
    tools_used: List[str] = Field(default_factory=lambda: ["none"], description="List of tools used (e.g. 'knowledge_base', 'web_search', 'general_knowledge').")

def _get_llm():
    settings = get_settings()
    
    if settings.groq_api_key:
        from langchain_groq import ChatGroq
        try:
            return ChatGroq(
                model=settings.groq_model_name,
                api_key=settings.groq_api_key,
                temperature=0.7
            )
        except Exception as e:
            print(f"Failed to init Groq: {e}")
            
    if settings.gemini_api_key:
        from langchain_google_genai import ChatGoogleGenerativeAI
        try:
            return ChatGoogleGenerativeAI(
                model=settings.gemini_model_name,
                google_api_key=settings.gemini_api_key,
                temperature=0.7
            )
        except Exception as e:
            print(f"Failed to init Gemini: {e}")
            
    raise ValueError("No valid LLM API key configured. Set GROQ_API_KEY in backend/.env.")

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
        print(f"Web search error (continuing with general knowledge): {e}")
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

    web_keywords = ["latest", "current", "recent", "news", "today", "compare", "vs", "versus", "update", "2024", "2025", "2026"]
    needs_web = (len(kb_results) == 0 and any(kw in user_message.lower() for kw in web_keywords))

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

    if not tools_used:
        tools_used.append("general_knowledge")

    context = "\n".join(context_parts) if context_parts else "No uploaded documents match this query. Answer using general intelligence and knowledge."
    
    history_str = ""
    if chat_history:
        for msg in chat_history[-6:]:
            role = "User" if msg["role"] == "user" else "Assistant"
            history_str += f"{role}: {msg['content']}\n"

    prompt_template = ChatPromptTemplate.from_messages([
        ("system", AGENT_SYSTEM_PROMPT),
        ("user", "CONTEXT FROM TOOLS / KNOWLEDGE BASE:\n{context}\n\nRECENT CHAT HISTORY:\n{history_str}\n\nUSER QUESTION: {user_message}")
    ])

    llm = _get_llm()

    try:
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
        print(f"Structured LLM invocation warning: {e}, using raw LLM fallback...")
        try:
            prompt = prompt_template.invoke({
                "context": context,
                "history_str": history_str,
                "user_message": user_message
            })
            raw_response = llm.invoke(prompt)
            answer_text = raw_response.content if hasattr(raw_response, 'content') else str(raw_response)
            return {
                "answer": answer_text,
                "citations": pre_citations,
                "tools_used": tools_used,
            }
        except Exception as err2:
            print(f"Fallback LLM execution error: {err2}")
            return {
                "answer": f"I was unable to complete your request. Error: {str(err2)}",
                "citations": [],
                "tools_used": ["none"],
            }
