# Sourcely — Multi-Source RAG Knowledge Assistant
### Engineering Design Doc + Agentic IDE Build Prompt

---

## 1. Project Overview

**Name:** Sourcely

**One-liner:** A web app where a user uploads or links any knowledge source (PDF, DOCX, YouTube video, website URL) and chats with it via an AI agent — grounded, cited answers, with the option to pull in live web info and auto-generated summaries/quizzes per source.

**Core value prop over a plain "chat with your PDF" app:**
- Multi-source **Knowledge Spaces** — query across several sources at once, not just one file.
- Every answer is **cited** (source + page/timestamp).
- An **agent**, not a static chain — it decides whether to answer from your sources, search the web, or do both, and says which it used.
- Every ingested source gets an **auto-summary and auto-generated quiz questions** for free, so the app is useful the moment ingestion finishes, before you've asked a single question.

**Scope for this build (all core, not stretch):**
1. Auth + Knowledge Spaces + multi-source ingestion (PDF/DOCX/YouTube/URL).
2. Cited RAG chat across a full Knowledge Space.
3. Agent mode: retriever tool + web-search tool, model picks and discloses which it used.
4. Auto-summary + auto-quiz generation triggered right after ingestion.

**True stretch goal (post-launch only):** a retrieval-quality evaluation dashboard (e.g. via RAGAS) — useful, but not needed for the product to work, so it's left out of this build.

---

## 2. Finalized Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Frontend | **Flutter (Web)** | Chat UI, upload screens, knowledge space management |
| Backend API | **Python + FastAPI** | Async endpoints for upload, ingest status, chat, agent |
| Orchestration | **LangChain (Python)** | Loaders, splitters, retrievers, chains, agents, output parsers |
| LLM | **Hugging Face Inference API** | via `HuggingFaceEndpoint` / `ChatHuggingFace` in LangChain |
| Embeddings | **Hugging Face `sentence-transformers` model** (e.g. `all-MiniLM-L6-v2`) via `HuggingFaceEmbeddings` | Free, hosted or local |
| Vector Store | **Chroma** | Local/self-hosted, free, persistent on disk |
| Auth + DB + File Storage | **Supabase** (free tier) | Postgres for metadata/chat history, Supabase Auth, Supabase Storage for raw files |
| Web search tool (for agent) | Any free-tier search API (e.g. Tavily free tier, or DuckDuckGo via LangChain's `DuckDuckGoSearchRun` — no key needed) | Used as a LangChain Tool |
| Background jobs | **FastAPI BackgroundTasks** (MVP) → Celery + Redis later if needed | Ingestion + summary/quiz generation shouldn't block the request |
| Deployment (backend) | Render / Railway free tier | |
| Deployment (frontend) | Firebase Hosting or any static host | Flutter web build |

---

## 3. System Architecture

```
┌─────────────┐      HTTPS      ┌──────────────────┐
│ Flutter Web │ ───────────────▶│   FastAPI Backend │
│   (Chat UI) │◀─────────────── │   + Agent layer   │
└─────────────┘                 └───────┬────────────┘
                                         │
             ┌───────────────┬──────────┼───────────────┬────────────────┐
             ▼               ▼          ▼                ▼                ▼
      ┌─────────────┐ ┌──────────┐ ┌───────────┐ ┌──────────────┐ ┌──────────────┐
      │  Supabase   │ │  Chroma  │ │ Hugging    │ │ Web Search   │ │  Retriever   │
      │ (Auth, DB,  │ │ (Vector  │ │ Face API   │ │ Tool (agent) │ │  Tool (agent)│
      │  Storage)   │ │  DB)     │ │(LLM+Embed) │ │              │ │              │
      └─────────────┘ └──────────┘ └───────────┘ └──────────────┘ └──────────────┘
```

**Flow — Ingestion (+ auto-summary/quiz):**
1. User uploads file / pastes URL / YouTube link via Flutter app.
2. Flutter calls `POST /sources` with file or link + `knowledge_space_id`.
3. FastAPI saves raw file to Supabase Storage, creates a `sources` row with `status=processing`.
4. Background task:
   - Correct LangChain loader extracts text → `RecursiveCharacterTextSplitter` chunks → `HuggingFaceEmbeddings` embeds → chunks upserted into the Chroma collection for that `knowledge_space_id`, with metadata (`source_id`, `source_type`, `page`/`timestamp`, `chunk_index`).
   - A structured-output chain (LangChain output parser) generates a **summary** and **3–5 quiz questions (with answers)** from the source's full text, saved onto the `sources` row.
5. `sources` row updated to `status=ready` (with `summary`, `quiz`) or `failed` with an error message.

**Flow — Agentic Chat:**
1. User sends a message tied to a `knowledge_space_id`.
2. Request goes to a LangChain **agent** (tool-calling), not a static chain, with two tools available:
   - `knowledge_base_search` — retrieves top-k chunks from that space's Chroma collection.
   - `web_search` — free web search tool, for when the user's question needs current/external info.
3. Agent decides which tool(s) to call (it may use just the retriever, just search, or both), then composes an answer that cites which tool/source each claim came from.
4. Answer + citations + "used sources: [knowledge base / web / both]" tag returned to Flutter.
5. Message + answer + citations saved to `messages` table.

---

## 4. Data Model (Supabase / Postgres)

```sql
users               -- managed by Supabase Auth

knowledge_spaces (
  id uuid pk,
  user_id uuid fk -> users,
  name text,
  created_at timestamp
)

sources (
  id uuid pk,
  knowledge_space_id uuid fk -> knowledge_spaces,
  type text,              -- 'pdf' | 'docx' | 'youtube' | 'url'
  original_name text,
  storage_path text,      -- Supabase Storage path (null for url/youtube)
  source_url text,        -- for youtube/url types
  status text,            -- 'processing' | 'ready' | 'failed'
  error_message text,
  chunk_count int,
  summary text,           -- auto-generated on ingest
  quiz jsonb,              -- auto-generated: [{question, answer}]
  created_at timestamp
)

conversations (
  id uuid pk,
  knowledge_space_id uuid fk -> knowledge_spaces,
  created_at timestamp
)

messages (
  id uuid pk,
  conversation_id uuid fk -> conversations,
  role text,               -- 'user' | 'assistant'
  content text,
  citations jsonb,          -- [{source_id, page/timestamp, snippet}]
  tools_used jsonb,         -- ['knowledge_base' | 'web_search']
  created_at timestamp
)
```

Chroma stores the actual vectors, one **collection per `knowledge_space_id`**, with chunk metadata pointing back to `source_id`.

---

## 5. API Endpoints (FastAPI)

```
POST   /auth/*                       (delegated to Supabase Auth on frontend, backend verifies JWT)

POST   /knowledge-spaces             create a new space
GET    /knowledge-spaces             list user's spaces
GET    /knowledge-spaces/{id}        get one space + its sources

POST   /sources                      upload file or submit url/youtube link
GET    /sources/{id}/status          poll ingestion status (returns summary+quiz once ready)

POST   /knowledge-spaces/{id}/chat   send a message to the agent, get answer + citations + tools_used
GET    /knowledge-spaces/{id}/messages   get chat history
```

---

## 6. Ingestion Pipeline — Loader Mapping

| Source type | LangChain loader | Notes |
|---|---|---|
| PDF | `PyPDFLoader` | keep page numbers in metadata |
| DOCX | `Docx2txtLoader` | |
| YouTube | `YoutubeLoader` (+ `youtube-transcript-api`) | keep timestamps in metadata |
| Website URL | `WebBaseLoader` | strip nav/boilerplate where possible |

All → `RecursiveCharacterTextSplitter` (chunk_size ~1000, overlap ~150) → `HuggingFaceEmbeddings` → Chroma.

Immediately after chunking, the **full extracted text** (pre-chunking) is also passed through a structured-output chain to generate `summary` + `quiz` for that source.

---

## 7. Agent Design

- Framework: LangChain tool-calling agent (e.g. `create_tool_calling_agent` + `AgentExecutor`).
- Tools:
  1. `knowledge_base_search(query)` → wraps Chroma retriever for the active `knowledge_space_id`, returns chunks + metadata.
  2. `web_search(query)` → wraps a free search tool (e.g. `DuckDuckGoSearchRun`), returns snippets + URLs.
- System prompt instructs the agent to:
  - Prefer `knowledge_base_search` first for questions about the uploaded sources.
  - Use `web_search` only when the question needs info outside the sources, or the user explicitly asks to compare source content with current info.
  - Always cite: source_id + page/timestamp for knowledge base hits, URL for web hits.
  - Say plainly when something isn't found in either.
- Chat history (last N messages) is passed in so follow-ups work.

---

## 8. Build Phases

1. **Phase 1 — Backend skeleton:** FastAPI project, Supabase connection, auth middleware, DB schema migration.
2. **Phase 2 — Ingestion:** upload endpoint, loaders, chunking, embeddings, Chroma storage, status polling.
3. **Phase 3 — Auto-summary/quiz:** structured-output chain run right after chunking, results saved to `sources`.
4. **Phase 4 — Agentic chat:** retriever tool + web search tool, agent executor, citation + tools_used formatting, chat history persistence.
5. **Phase 5 — Flutter frontend:** auth screens, knowledge space list, upload UI, source cards showing summary/quiz, chat UI with citations and a "used: knowledge base / web" tag per message.
6. **Phase 6 (post-launch, true stretch):** RAGAS-based retrieval evaluation dashboard.

---

## 9. Complete Prompt for Agentic IDE

Copy everything in the block below into your agentic IDE (e.g. Cursor/Claude Code/Windsurf) as the initial project prompt.

```
Build a full-stack project called "Sourcely" — an agentic, multi-source RAG
knowledge assistant.

OVERVIEW:
Users create "Knowledge Spaces," upload or link knowledge sources into a space
(PDF, DOCX, YouTube video URL, or website URL). On ingestion, each source
automatically gets a generated summary and a short quiz (3-5 Q&A pairs).
Users then chat with an AGENT (not a static chain) tied to that Knowledge
Space. The agent has two tools: a knowledge-base retriever (searches the
space's ingested sources) and a web search tool. It decides which tool(s) to
use per question, and every answer must cite its sources: for knowledge-base
hits, cite source name + page number or YouTube timestamp; for web hits,
cite the URL. The agent should also report which tool(s) it used.

TECH STACK (use exactly this):
- Frontend: Flutter (web target)
- Backend: Python + FastAPI
- Orchestration: LangChain (Python), using a tool-calling agent
  (create_tool_calling_agent + AgentExecutor)
- LLM: Hugging Face Inference API (via LangChain's HuggingFaceEndpoint / ChatHuggingFace)
- Embeddings: Hugging Face sentence-transformers model (all-MiniLM-L6-v2) via HuggingFaceEmbeddings
- Vector store: Chroma (persistent local instance, one collection per knowledge_space_id)
- Web search tool: LangChain's DuckDuckGoSearchRun (no API key required) or Tavily free tier
- Auth, Postgres DB, and file storage: Supabase (free tier)
- Background ingestion: FastAPI BackgroundTasks

DATA MODEL (Postgres via Supabase):
- knowledge_spaces(id, user_id, name, created_at)
- sources(id, knowledge_space_id, type[pdf|docx|youtube|url], original_name,
  storage_path, source_url, status[processing|ready|failed], error_message,
  chunk_count, summary, quiz jsonb, created_at)
- conversations(id, knowledge_space_id, created_at)
- messages(id, conversation_id, role[user|assistant], content, citations jsonb,
  tools_used jsonb, created_at)

BACKEND REQUIREMENTS:
1. FastAPI app with routers for: knowledge-spaces, sources, chat.
2. JWT verification middleware using Supabase Auth tokens.
3. POST /knowledge-spaces, GET /knowledge-spaces, GET /knowledge-spaces/{id}
4. POST /sources — accepts either a file upload (pdf/docx) or a JSON body with
   a youtube/url link, plus knowledge_space_id. Saves file to Supabase Storage
   (if applicable), inserts a `sources` row with status=processing, and kicks
   off a background ingestion task.
5. Ingestion task:
   a. Pick the right LangChain loader based on source type (PyPDFLoader,
      Docx2txtLoader, YoutubeLoader, WebBaseLoader).
   b. Split with RecursiveCharacterTextSplitter (chunk_size=1000, chunk_overlap=150),
      embed with HuggingFaceEmbeddings, upsert into the Chroma collection named
      after knowledge_space_id, with metadata: source_id, source_type,
      page or timestamp, chunk_index.
   c. Run the full extracted text through a structured-output chain (LangChain
      output parser with a Pydantic schema: summary: str, quiz: List[{question,
      answer}]) and save the result onto the sources row.
   d. Update the source's status to ready/failed.
6. GET /sources/{id}/status — returns current ingestion status, summary, and quiz.
7. POST /knowledge-spaces/{id}/chat — routes the user's message to a LangChain
   tool-calling agent scoped to that knowledge_space_id, with two tools:
   - knowledge_base_search: retrieves top-4 chunks from that space's Chroma
     collection.
   - web_search: DuckDuckGoSearchRun (or equivalent free tool).
   System prompt: prefer knowledge_base_search first; only use web_search when
   the question needs info outside the ingested sources or the user explicitly
   wants a comparison with current info; always cite sources (source_id +
   page/timestamp, or URL for web); state plainly if nothing relevant is found.
   Save user message + assistant response (citations, tools_used) to `messages`,
   return answer + citations + tools_used to the client.
8. GET /knowledge-spaces/{id}/messages — chat history for a space.

FRONTEND REQUIREMENTS (Flutter Web):
1. Auth screens (sign up / log in) using Supabase Auth Flutter SDK.
2. Home screen: list of the user's Knowledge Spaces, button to create a new one.
3. Knowledge Space screen: list of sources as cards showing status badge
   (processing/ready/failed), and once ready, an expandable summary + quiz
   for that source; an "Add Source" button supporting file upload (pdf/docx)
   and link paste (youtube/url); and a chat panel.
4. Chat panel: message list (user/assistant bubbles), input box. Each
   assistant message shows citations as expandable tags (source name +
   page/timestamp, or web URL) and a small "used: knowledge base / web"
   indicator.
5. Polling or simple refresh for source ingestion status until status=ready.

NON-FUNCTIONAL:
- Keep secrets (Supabase keys, HF API token) in environment variables, never hardcoded.
- Handle ingestion failures gracefully and surface the error_message to the UI.
- Write clean, modular code: separate ingestion logic, summary/quiz generation,
  agent/tool logic, and API routes into distinct modules on the backend.
- Add a README explaining setup: required env vars, how to run the backend
  (uvicorn), how to run Chroma locally, and how to run the Flutter web app.

START by scaffolding the backend (FastAPI project structure, DB models,
Supabase client setup) and the ingestion pipeline (including summary/quiz
generation) first, since chat depends on it. Then build the agent/chat
endpoint, then the Flutter frontend.
```

---

## 10. Notes for you (not part of the IDE prompt)

- Hugging Face free inference has rate limits and cold-start latency on some models — pick a small, fast hosted model for early testing so the demo (and the agent's tool-calling reasoning, which needs multiple LLM calls) feels responsive.
- Tool-calling reliability varies a lot by model on the free HF tier — test the agent early with a couple of different hosted models before committing; not every free model handles function/tool calling well.
- DuckDuckGoSearchRun needs no API key, which is why it's the default web tool here — swap for Tavily's free tier later if you want more structured/reliable search results.
- Chroma persists to disk by default — make sure your backend host has a writable volume, or you'll lose the vector store on redeploy.
- Keep chunk metadata (source_id, page/timestamp) disciplined from day one — retrofitting citations later is much more painful than building them in from the first ingestion pipeline.
