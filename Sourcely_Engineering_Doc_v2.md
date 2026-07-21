# Sourcely — Engineering Doc v2 (Update Pass)
### UI/UX redesign, backend simplification, LLM swap, PDF export

This doc describes changes to the **existing, already-built** Sourcely project (Flutter + FastAPI + LangChain + Supabase + Chroma). Give this to your agentic IDE as a follow-up prompt — it should modify the existing codebase, not start from scratch.

---

## 1. Summary of Changes

| Area | Change |
|---|---|
| UI — Home screen | Knowledge Spaces shown as square cards, each with an emoji, in a grid |
| UI — Space screen | Restructured into 3 panels: Sources (top-left, max half height, max 6 sources), Conversation History (bottom-left, rename/delete), Chat (right, main) |
| UI — Theme | New teal-accent light/dark theme (colors below) |
| Backend — Ingestion | **Remove** auto-summary + auto-quiz generation entirely |
| Backend — LLM | **Swap** primary LLM provider to fix weak/unstructured responses |
| Backend — Agent | Tighten and simplify the agent so it's more reliable and specific, not generically wired |
| Backend — New feature | Generate a downloadable PDF of any chat response, on request |

---

## 2. Updated Tech Stack

| Layer | Choice | Change from v1 |
|---|---|---|
| Frontend | Flutter (Web) | unchanged |
| Backend API | Python + FastAPI | unchanged |
| Orchestration | LangChain (Python) | unchanged |
| **LLM (primary)** | **Groq API — `llama-3.3-70b-versatile`** | **changed** from Hugging Face-hosted Mistral-7B |
| LLM (fallback, optional) | Google Gemini API free tier (`gemini-2.0-flash`) | new — optional second provider |
| Embeddings | Hugging Face `sentence-transformers/all-MiniLM-L6-v2` | unchanged (embeddings were never the problem — keep it) |
| Vector Store | Chroma | unchanged |
| Auth + DB + Storage | Supabase | unchanged |
| Web search tool | DuckDuckGoSearchRun | unchanged |
| **New: PDF generation** | **`reportlab`** (Python) | new — for exporting chat responses |

### Why Groq instead of Hugging Face Inference API for the LLM

Your reported issue — responses that are "not efficient, not properly structured" — is a known weak point of small models like Mistral-7B served on the free HF Inference API: slow cold starts, inconsistent instruction-following, and unreliable tool-calling, which matters a lot for an agent that must cite sources correctly.

**Groq** is the recommended swap because:
- Free tier with a genuinely large daily token allowance and very high requests-per-minute limits (best "free credits" among the realistic no-cost options right now).
- Extremely fast inference (LPU hardware) — noticeably snappier chat UX.
- Hosts **Llama 3.3 70B Versatile**, a much stronger model than Mistral-7B for instruction-following, structured output, and function/tool calling — directly fixes the "not properly structured" complaint.
- Drop-in with LangChain via `langchain-groq`'s `ChatGroq`, so the swap is a config + one class change, not a rewrite.

Keep **Gemini 2.0 Flash free tier** wired in as a fallback provider (env-var switchable) — useful if you ever hit Groq's rate limit during heavy testing, and Gemini's free tier is also generous with a huge context window.

Hugging Face is kept **only** for embeddings (`all-MiniLM-L6-v2`), which were never the source of the quality problem and are fine to keep local/free.

---

## 3. UI/UX Redesign

### 3.1 Brand Theme

```
Primary Accent:            #14B8A6   (Vibrant Teal)

Light theme:
  Background:               #FFFFFF
  Text:                     #27272A

Dark theme:
  Background:               #121212
  Text:                     #E4E4E7
```

Apply via a single `AppTheme` (Flutter `ThemeData` light/dark pair) referenced everywhere — no hardcoded colors in widgets.

### 3.2 Home Screen — Knowledge Spaces Grid

- Replace any list-style view with a **grid of square cards**.
- Each card: large emoji (auto-picked based on space name/topic, or user-selectable at creation) centered/top of the card, space name below, source count + last-updated date as a small subtitle.
- "Create new knowledge space" as its own square card (dashed border or accent `+`), first in the grid — same pattern as the reference screenshot (a "+" create card followed by content cards).
- Grid should be responsive (wrap based on width) for the Flutter web target.

### 3.3 Knowledge Space Screen — 3-Panel Layout

Reference layout: a left sidebar split into two stacked panels, plus a main chat panel on the right.

```
┌───────────────┬─────────────────────────────┐
│  SOURCES        │                             │
│  (top-left,     │                             │
│  max 50% of     │                             │
│  sidebar height)│         CHAT PANEL          │
│  max 6 sources  │        (main, right)        │
├───────────────┤                             │
│ CONVERSATIONS   │                             │
│ (bottom-left)   │                             │
│                 │                             │
└───────────────┴─────────────────────────────┘
```

**Panel 1 — Sources (top-left)**
- Capped height: **max ~50% of the sidebar's vertical space** — becomes independently scrollable if it has multiple sources, rather than pushing the conversations panel down.
- "Upload" button supports **multi-file selection** in one action (pdf/docx) plus a way to paste a URL/YouTube link.
- **Hard cap: 6 sources per Knowledge Space.** Once at 6, disable/hide the upload control and show a small "6/6 sources — remove one to add another" note.
- Each source shown as a compact row/chip: type icon, name, status badge (processing/ready/failed). No summary/quiz preview anymore (removed per backend change below).

**Panel 2 — Conversation History (bottom-left)**
- List of past conversations *for this Knowledge Space only*.
- Each item: conversation name (auto-generated from first message, editable) + last-updated time.
- Actions per conversation: **rename** (inline edit) and **delete** (with confirm).
- Selecting a conversation loads it into the chat panel; a "+ New conversation" affordance starts a fresh one.

**Panel 3 — Chat (main, right)**
- Standard chat panel: message bubbles, citations as expandable tags, "tools used" indicator (unchanged behavior from v1, still cites knowledge base / web).
- New: each **assistant message** gets a small "Export as PDF" action — see Section 5.

---

## 4. Backend Changes

### 4.1 Remove Auto-Summary/Quiz

- Delete `services/summary_quiz.py` and its call from the ingestion pipeline.
- Remove `summary` and `quiz` columns from the `sources` table (migration).
- Remove any frontend code rendering summary/quiz on source cards.
- Ingestion pipeline becomes: extract → chunk → embed → store in Chroma → mark `ready`. Nothing else.

### 4.2 LLM Swap

- Add `langchain-groq` to `requirements.txt`; remove the HF chat-model wiring (keep `langchain-huggingface` only for `HuggingFaceEmbeddings`).
- `config.py`: add `GROQ_API_KEY`, `GROQ_MODEL` (default `llama-3.3-70b-versatile`), and optional `GEMINI_API_KEY` / `GEMINI_MODEL` for the fallback path.
- `services/agent.py`: initialize the agent's LLM via `ChatGroq(model=GROQ_MODEL, api_key=GROQ_API_KEY, temperature=0.2)`. Add a simple provider-selection wrapper so switching to Gemini is a config change, not a code change.

### 4.3 Make the Agent More Specific / Reliable

Current issue: the agent flow is generic and produces inconsistent structure. Tighten it:
- Give the agent a **strict system prompt template** with explicit output structure: a short direct answer first, then a "Sources" section listing each citation used (source name + page/timestamp, or URL).
- Lower `temperature` (e.g. 0.2) for more consistent, less rambling output.
- Explicitly cap tool calls per turn (e.g. max 1 knowledge-base call + 1 web-search call) so the agent doesn't loop or over-call tools.
- Validate the final answer against a lightweight Pydantic output schema (`answer: str`, `citations: List[Citation]`, `tools_used: List[str]`) using LangChain's structured output parsing, so the API response to the frontend is always well-formed — this is what actually fixes "not properly structured," independent of which LLM is used.

### 4.4 New Feature: Export Chat Response as PDF

- New endpoint: `POST /messages/{id}/export-pdf`.
- Uses `reportlab` to render the assistant's answer (formatted: heading, answer text, a "Sources" section listing citations) into a PDF.
- Generated PDF is uploaded to Supabase Storage (a `exports/` path) and the endpoint returns a signed download URL.
- Frontend: "Export as PDF" action on each assistant message triggers this call, then opens/downloads the returned URL.
- This is per-message, on-demand — no PDFs are generated unless the user explicitly asks.

---

## 5. Updated Data Model (Postgres via Supabase)

```sql
knowledge_spaces (
  id uuid pk,
  user_id uuid fk -> users,
  name text,
  emoji text,              -- NEW: emoji shown on the space's card
  created_at timestamp
)

sources (
  id uuid pk,
  knowledge_space_id uuid fk -> knowledge_spaces,
  type text,               -- 'pdf' | 'docx' | 'youtube' | 'url'
  original_name text,
  storage_path text,
  source_url text,
  status text,              -- 'processing' | 'ready' | 'failed'
  error_message text,
  chunk_count int,
  created_at timestamp
  -- summary, quiz columns REMOVED
)

conversations (
  id uuid pk,
  knowledge_space_id uuid fk -> knowledge_spaces,
  name text,                -- NEW: editable, auto-generated from first message by default
  created_at timestamp,
  updated_at timestamp       -- NEW: for sorting conversation history
)

messages (
  id uuid pk,
  conversation_id uuid fk -> conversations,
  role text,
  content text,
  citations jsonb,
  tools_used jsonb,
  created_at timestamp
)
```

**Enforcement:** the 6-source cap is enforced in the backend (`POST /sources` returns a 400 if `knowledge_space_id` already has 6 sources), not just hidden in the UI.

---

## 6. Updated API Endpoints

```
POST   /knowledge-spaces                       create (now accepts optional `emoji`)
GET    /knowledge-spaces                       list (returns emoji, source_count, updated_at for card grid)
GET    /knowledge-spaces/{id}                  get space + its sources + its conversations

POST   /sources                                upload/link a source (400 if space already has 6)
GET    /sources/{id}/status                    ingestion status only (no summary/quiz)
DELETE /sources/{id}                           remove a source (frees a slot toward the 6 cap)

POST   /knowledge-spaces/{id}/conversations             create a new conversation
GET    /knowledge-spaces/{id}/conversations              list conversations for this space
PATCH  /conversations/{id}                     rename a conversation
DELETE /conversations/{id}                     delete a conversation (+its messages)

POST   /conversations/{id}/chat                send a message in a conversation, get answer + citations + tools_used
GET    /conversations/{id}/messages            message history for a conversation

POST   /messages/{id}/export-pdf               NEW — generate + return a download URL for that message as PDF
```

---

## 7. Complete Prompt for Agentic IDE

```
Update the existing "Sourcely" project (Flutter + FastAPI + LangChain + Supabase
+ Chroma) with the following changes. Modify the existing codebase in place —
do not scaffold a new project.

THEME:
Apply this color theme app-wide via a single theme definition (no hardcoded
colors in widgets):
- Primary accent: #14B8A6
- Light theme: background #FFFFFF, text #27272A
- Dark theme: background #121212, text #E4E4E7

UI CHANGE 1 — Home screen (Knowledge Spaces):
Replace the current list view with a grid of square cards. Each card shows a
large emoji (stored per knowledge_space, user-selectable at creation, sensible
default otherwise), the space name, and a subtitle with source count + last
updated date. Include a "Create new knowledge space" card (accent-colored plus
icon) as the first item in the grid. Grid should reflow responsively on web.

UI CHANGE 2 — Knowledge Space screen (3-panel layout):
Restructure into: a left sidebar split into two stacked panels (Sources on
top, Conversations below), and a main chat panel on the right.
- Sources panel: capped at roughly half the sidebar's height and independently
  scrollable if needed. Multi-file upload button (pdf/docx) plus a way to
  submit a URL or YouTube link. Hard cap of 6 sources per knowledge space —
  enforce this in the backend (return 400 if already at 6) and reflect it in
  the UI (disable/hide upload past 6, show "6/6 sources"). Each source shown
  as a compact row: icon, name, status badge. No summary/quiz preview.
- Conversations panel: list of conversations scoped to this knowledge space
  only, each with an editable name and a delete action (with confirmation).
  Selecting one loads it into the chat panel. Include a "+ New conversation"
  control.
- Chat panel: existing chat UI (messages, citations, tools-used indicator),
  plus a new "Export as PDF" action on every assistant message.

BACKEND CHANGE 1 — Remove auto-summary/quiz:
Delete the summary/quiz generation service and its call in the ingestion
pipeline. Remove `summary` and `quiz` columns from the `sources` table via a
migration. Remove any frontend rendering of summary/quiz.

BACKEND CHANGE 2 — Swap the LLM provider:
Replace the Hugging Face-hosted chat model with Groq
(model: llama-3.3-70b-versatile) via `langchain-groq`'s ChatGroq, using a new
GROQ_API_KEY env var. Keep Hugging Face only for embeddings
(sentence-transformers/all-MiniLM-L6-v2) — do not change the embeddings setup.
Add an optional fallback provider path to Google Gemini
(model: gemini-2.0-flash) via a GEMINI_API_KEY env var, selectable by config,
for use if Groq's rate limit is hit.

BACKEND CHANGE 3 — Make the agent more reliable/specific:
Give the agent a strict system prompt: answer first, then a "Sources" section
listing every citation used (source name + page/timestamp, or URL for web
results). Set temperature to 0.2. Cap tool calls to at most one
knowledge-base search and one web search per turn. Validate and shape the
final response through a Pydantic schema (answer: str, citations: list of
{source, location}, tools_used: list of str) using LangChain structured
output parsing, so every API response to the frontend has a consistent shape
regardless of what the model returns.

BACKEND CHANGE 4 — PDF export of chat responses:
Add POST /messages/{id}/export-pdf. Use the `reportlab` Python library to
render that assistant message into a PDF (heading, the answer text, then a
"Sources" section listing its citations). Upload the generated PDF to
Supabase Storage under an `exports/` path and return a signed download URL.
Wire the frontend's new "Export as PDF" button on each assistant message to
call this endpoint and then open/download the returned URL. Only generate a
PDF on explicit user request — never automatically.

DATA MODEL CHANGES:
- knowledge_spaces: add `emoji` (text) column.
- sources: remove `summary`, `quiz` columns.
- conversations: new table if not already present as a first-class entity —
  id, knowledge_space_id, name, created_at, updated_at. Chat history moves
  under conversations (messages.conversation_id instead of directly under
  knowledge_space_id, if not already structured that way).
- Enforce the 6-source-per-space cap at the database/service layer, not just
  in the UI.

API CHANGES:
Add: POST/GET /knowledge-spaces/{id}/conversations, PATCH and DELETE
/conversations/{id}, POST /conversations/{id}/chat, GET
/conversations/{id}/messages, POST /messages/{id}/export-pdf.
Update GET /knowledge-spaces to return emoji, source_count, and updated_at for
each space (needed for the new card grid).
Update POST /sources to reject uploads past the 6-source cap with a 400 and a
clear error message.

Apply these changes incrementally: backend data model + LLM swap first
(since the frontend depends on the new conversation-scoped endpoints), then
backend agent/PDF changes, then the two frontend UI changes, then theme
application app-wide last (it's the safest to apply broadly at the end).
```

---

## 8. Notes for you (not part of the IDE prompt)

- Groq's free tier is generous but does have per-model rate limits that reset frequently (per-minute + per-day) — if you're demoing live and hit a limit, that's exactly what the Gemini fallback path is for; don't skip wiring it even though it's "optional."
- `langchain-groq` and `ChatGroq` support tool/function calling with Llama 3.3 70B, so your existing agent tool definitions (`knowledge_base_search`, `web_search`) should carry over with minimal changes — the swap is mostly in the LLM initialization, not the agent logic itself.
- Enforcing the 6-source cap server-side (not just hiding the button) matters — someone could otherwise hit the upload endpoint directly and bust the limit.
- `reportlab` has no external service dependency (pure Python), so PDF export won't add another API key or cost to the stack.
