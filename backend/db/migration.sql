-- ============================================================
-- Sourcely Database Schema — Supabase / Postgres
-- Run this in the Supabase SQL Editor to set up the database.
-- ============================================================

-- Enable UUID extension (usually already enabled in Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Knowledge Spaces ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS knowledge_spaces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_knowledge_spaces_user_id ON knowledge_spaces(user_id);

-- RLS: Users can only see/manage their own spaces
ALTER TABLE knowledge_spaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own knowledge spaces"
    ON knowledge_spaces FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own knowledge spaces"
    ON knowledge_spaces FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own knowledge spaces"
    ON knowledge_spaces FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own knowledge spaces"
    ON knowledge_spaces FOR UPDATE
    USING (auth.uid() = user_id);

-- ─── Sources ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    knowledge_space_id UUID NOT NULL REFERENCES knowledge_spaces(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('pdf', 'docx', 'youtube', 'url')),
    original_name TEXT,
    storage_path TEXT,            -- Supabase Storage path (null for url/youtube)
    source_url TEXT,              -- For youtube/url types
    status TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('processing', 'ready', 'failed')),
    error_message TEXT,
    chunk_count INTEGER,
    summary TEXT,                 -- Auto-generated on ingest
    quiz JSONB,                   -- Auto-generated: [{question, answer}]
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sources_knowledge_space_id ON sources(knowledge_space_id);
CREATE INDEX IF NOT EXISTS idx_sources_status ON sources(status);

-- RLS: Users can manage sources through their knowledge spaces
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view sources in their spaces"
    ON sources FOR SELECT
    USING (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create sources in their spaces"
    ON sources FOR INSERT
    WITH CHECK (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update sources in their spaces"
    ON sources FOR UPDATE
    USING (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete sources in their spaces"
    ON sources FOR DELETE
    USING (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

-- ─── Conversations ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    knowledge_space_id UUID NOT NULL REFERENCES knowledge_spaces(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_knowledge_space_id ON conversations(knowledge_space_id);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view conversations in their spaces"
    ON conversations FOR SELECT
    USING (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create conversations in their spaces"
    ON conversations FOR INSERT
    WITH CHECK (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete conversations in their spaces"
    ON conversations FOR DELETE
    USING (
        knowledge_space_id IN (
            SELECT id FROM knowledge_spaces WHERE user_id = auth.uid()
        )
    );

-- ─── Messages ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    citations JSONB,              -- [{source_id, page/timestamp, snippet}]
    tools_used JSONB,             -- ['knowledge_base' | 'web_search']
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their conversations"
    ON messages FOR SELECT
    USING (
        conversation_id IN (
            SELECT c.id FROM conversations c
            JOIN knowledge_spaces ks ON c.knowledge_space_id = ks.id
            WHERE ks.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create messages in their conversations"
    ON messages FOR INSERT
    WITH CHECK (
        conversation_id IN (
            SELECT c.id FROM conversations c
            JOIN knowledge_spaces ks ON c.knowledge_space_id = ks.id
            WHERE ks.user_id = auth.uid()
        )
    );

-- ─── Storage Bucket ──────────────────────────────────────────

-- Create the storage bucket for source files (run this separately or via Supabase dashboard)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('source-files', 'source-files', false);

-- Storage RLS policies
-- CREATE POLICY "Users can upload source files"
--     ON storage.objects FOR INSERT
--     WITH CHECK (bucket_id = 'source-files' AND auth.role() = 'authenticated');

-- CREATE POLICY "Users can read source files"
--     ON storage.objects FOR SELECT
--     USING (bucket_id = 'source-files' AND auth.role() = 'authenticated');

-- ─── Service Role Bypass ─────────────────────────────────────
-- The backend uses the service_role key which bypasses RLS.
-- This is intentional for background tasks (ingestion, status updates).

-- Grant service role full access (already done by default in Supabase)
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
