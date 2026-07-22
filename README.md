# Sourcely 🧠

**Sourcely** is an intelligent, cross-platform knowledge assistant built with **Flutter** and **FastAPI**. It empowers users to create isolated "Knowledge Spaces," upload various document formats, and interact with a powerful AI agent using Retrieval-Augmented Generation (RAG). 

Whether you're analyzing resumes, summarizing YouTube videos, or extracting data from spreadsheets, Sourcely brings your documents to life through natural language conversation.

---

## 🌟 Key Features

- **Knowledge Spaces**: Organize your documents into distinct projects or topics (capped at 6 sources per space to maintain high performance).
- **Multi-Modal Ingestion**: Support for PDFs, Word Documents (.docx), Spreadsheets (.csv, .xlsx), Web Links, and YouTube URLs.
- **Agentic RAG Chat**: Chat intelligently with your documents. The AI retrieves highly relevant context using ChromaDB and HuggingFace embeddings.
- **Explicit Mentions**: Use the `@` symbol in chat to force the AI to only consider specific uploaded sources for highly targeted, precise answers.
- **Strict Output Formatting**: Ask for bullet points, tables, or summaries, and the AI strictly adheres to the requested format—dropping all unnecessary conversational fluff.
- **Robust Exception Handling**: Professional, user-friendly dialogs prevent unsupported file types and handle backend errors gracefully.

---

## 🛠️ Architecture & Working Flow

The following flowchart illustrates how data moves through Sourcely, from the moment a user uploads a file to when the AI delivers an answer.

<img width="6700" height="7245" alt="User Interaction Pipeline-2026-07-22-171107" src="https://github.com/user-attachments/assets/d90095a7-eb23-40a6-a370-cca0d4103e56" />

![Architecture & Working Flow](architecture.png)

---

## 💻 Tech Stack

### Frontend (Mobile & Web)
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **File Handling**: `file_picker`
- **UI/UX**: Custom Material 3 theme, sleek dialogs, micro-animations (`flutter_animate`).

### Backend (API & AI)
- **Framework**: FastAPI (Python)
- **Agent Orchestration**: LangChain
- **Vector Database**: ChromaDB
- **Embeddings**: HuggingFace (`sentence-transformers`)
- **Database & Auth**: Supabase (PostgreSQL)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Python 3.10+](https://www.python.org/downloads/)
- A [Supabase](https://supabase.com/) Project

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Set up your `.env` file with your Supabase credentials and LLM API keys.
5. Run the server:
   ```bash
   ./start_backend.sh
   # OR: fastapi dev app/main.py
   ```

### Frontend Setup
1. Navigate to the root directory.
2. Install Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 🎯 System Prompt Guidelines

Sourcely's AI is governed by strict system prompts to ensure a premium, predictable experience:
1. **Default Formatting**: Uses **Bold Titles** and clean paragraphs.
2. **User Overrides**: When users request specific structures (e.g., "bullet points only"), the AI completely drops introductory filler and titles, delivering exact formats instantly.

## 🧪 Testing

Sourcely includes a comprehensive testing suite to ensure high code quality.

- **Unit Tests**: Test core logic and models.
  ```bash
  flutter test test/models/
  ```
- **Widget Tests**: Test UI components in isolation (e.g., Loading shimmer).
  ```bash
  flutter test test/widgets/
  ```
- **App Integration Tests**: End-to-End widget tests with mocked providers to simulate app-wide rendering.
  ```bash
  flutter test test/app_test.dart
  ```

---
*Developed by Muhammad Maaz Saqib.*
