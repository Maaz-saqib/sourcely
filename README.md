# Sourcely — Multi-Source RAG Knowledge Assistant

A full-stack agentic RAG knowledge assistant. Upload PDFs, DOCX files, YouTube videos, or website URLs into **Knowledge Spaces**, then chat with an AI agent that searches your sources (and optionally the web) to give you cited, grounded answers.

## ✨ Features

- **Multi-Source Knowledge Spaces** — Organize and query across multiple sources at once
- **Auto-Summary & Quiz** — Every ingested source gets an AI-generated summary and quiz questions
- **Cited Answers** — Every response cites its sources (document + page, or web URL)
- **Agentic Chat** — AI decides whether to search your knowledge base, the web, or both
- **Tool Transparency** — Each answer shows which tools (Knowledge Base / Web Search) were used

## 🏗️ Architecture

```
┌─────────────────┐       HTTPS        ┌──────────────────────┐
│ Flutter App      │ ──────────────────▶│   FastAPI Backend     │
│ (Web / Android)  │◀────────────────── │   + Agent Layer       │
└─────────────────┘                     └───────┬──────────────┘
                                                │
         ┌──────────────┬──────────┬────────────┼───────────────┐
         ▼              ▼          ▼            ▼               ▼
   ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Supabase  │ │  Chroma  │ │ HF API   │ │ DuckDuck │ │ Retriever│
   │(Auth, DB, │ │ (Vector  │ │(LLM +    │ │ Go Search│ │   Tool   │
   │ Storage)  │ │   DB)    │ │Embedding)│ │          │ │          │
   └───────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Python 3.10+** and `pip`
- **Flutter 3.10+**
- **Supabase** project (free tier)
- **Hugging Face** API token (free)

### 1. Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **Authentication** → **Providers** → Enable **Email** sign-up
3. Go to **Storage** → Create a new bucket named `source-files` (private)
4. Go to **SQL Editor** → Run the migration script:

```bash
# Copy and paste the contents of backend/db/migration.sql into the SQL Editor
```

5. Note down from **Settings** → **API**:
   - Project URL
   - `anon` public key
   - `service_role` secret key
   - JWT Secret (Settings → API → JWT Settings)

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your actual keys:
#   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
#   SUPABASE_JWT_SECRET, HUGGINGFACE_API_TOKEN

# Run the backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`. Check `http://localhost:8000/docs` for the interactive API docs.

### 3. Flutter Frontend Setup

```bash
# From the project root
cd /path/to/sourcely

# Install dependencies
flutter pub get

# Update Supabase config
# Edit lib/config/constants.dart with your Supabase URL and anon key
# Or pass them as dart-define:
# flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Run on Web
flutter run -d chrome

# Run on Android
flutter run -d android

# Build for Web (production)
flutter build web --release

# Build for Android (APK)
flutter build apk --release
```

## 📁 Project Structure

```
sourcely/
├── backend/                    # Python FastAPI backend
│   ├── app/
│   │   ├── main.py            # FastAPI entrypoint
│   │   ├── config.py          # Settings (env vars)
│   │   ├── auth.py            # JWT verification
│   │   ├── database.py        # Supabase client
│   │   ├── models.py          # Pydantic schemas
│   │   ├── routers/
│   │   │   ├── knowledge_spaces.py  # CRUD for spaces
│   │   │   ├── sources.py          # Upload & status
│   │   │   └── chat.py             # Agentic chat
│   │   └── services/
│   │       ├── ingestion.py        # Document processing pipeline
│   │       ├── summary_quiz.py     # Auto-summary & quiz gen
│   │       └── agent.py            # RAG agent with tools
│   ├── db/
│   │   └── migration.sql      # Supabase schema
│   ├── requirements.txt
│   └── .env.example
│
├── lib/                        # Flutter frontend
│   ├── main.dart              # App entrypoint
│   ├── config/
│   │   ├── theme.dart         # Dark theme + design system
│   │   └── constants.dart     # API URLs, config
│   ├── models/                # Data models
│   ├── services/              # Auth, API, storage services
│   ├── providers/             # State management
│   ├── screens/               # Full-page views
│   └── widgets/               # Reusable UI components
│
├── android/                    # Android platform files
├── web/                        # Web platform files
├── pubspec.yaml               # Flutter dependencies
└── README.md
```

## 🔑 Environment Variables

### Backend (.env)

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key |
| `SUPABASE_JWT_SECRET` | JWT secret from Supabase settings |
| `HUGGINGFACE_API_TOKEN` | HuggingFace API token |
| `CHROMA_PERSIST_DIR` | Directory for Chroma DB persistence (default: `./chroma_data`) |
| `LLM_MODEL_NAME` | HF model for chat (default: `mistralai/Mistral-7B-Instruct-v0.3`) |
| `EMBEDDINGS_MODEL_NAME` | HF embeddings model (default: `sentence-transformers/all-MiniLM-L6-v2`) |

### Frontend

Update `lib/config/constants.dart` or pass via `--dart-define`:

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Web + Android) |
| Backend | Python + FastAPI |
| Orchestration | LangChain (Python) |
| LLM | HuggingFace Inference API |
| Embeddings | sentence-transformers/all-MiniLM-L6-v2 |
| Vector Store | Chroma (local persistent) |
| Web Search | DuckDuckGo (no API key) |
| Auth + DB + Storage | Supabase (Postgres) |

## 📝 License

MIT
