# AI Integration — Extraction, People Management, Semantic Search

## Goal

Add AI-powered intelligence to Hub: extract summaries and signals from transcripts, let users manage people context (employee vs. client), and enable semantic search via `!` prefix in the search box.

## 1. People Management

### Schema Change

Add `role` and `context` fields to the `people` table:

```sql
ALTER TABLE people ADD COLUMN role varchar(20) DEFAULT 'unknown';
ALTER TABLE people ADD COLUMN context text DEFAULT '';
```

**Role values:** `employee`, `client`, `external`, `unknown`

**Context:** free-text description. Examples:
- "CTO, manages mobile and design teams"
- "GM at Willow Bend Golf Club"
- "Sales rep at competing product"

### UI

Simple people management page at `/people`:
- Table listing all detected people with name, role (dropdown), context (editable text field)
- Inline editing — change role or context, auto-saves on blur
- Shows conversation count per person
- No separate create/delete — people are auto-created from transcript participants

### How It's Used by AI

When processing a transcript, the system prompt includes a people roster:

```
TenFore employees in this conversation:
- Jarrette Schule (CTO, manages mobile and design teams)
- Weston Farnsworth (developer)

External participants (likely clients):
- Ryan (unknown context)
```

This lets the model distinguish internal discussion from client feedback.

## 2. AI Extraction Pipeline

### Flow

```
RawDocument (exists) → Processor (Oban job) → Claude Sonnet API
                                                    ↓
                                        ProcessedDocument (summary, action_items)
                                        Signals (typed, with speaker + content)
                                        Client resolution (link to client records)
```

### Trigger

Processing is NOT automatic on ingest (to control costs). Instead:
- **Mix task:** `mix hub.process` — processes all unprocessed documents
- **Mix task with ID:** `mix hub.process <document_id>` — process a single document
- **Future:** button on document detail page to trigger processing

### Prompt Design

System prompt includes:
- Company context (TenFore = golf course management software)
- People roster with roles and context (from the people table)
- Signal type definitions

Extraction prompt requests JSON with:
- `summary`: 2-3 sentences, focused on decisions and outcomes
- `action_items`: `[{text, person (if mentioned)}]` — no forced assignees, just capture what was said
- `signals`: `[{type, content (quote or close paraphrase), speaker, confidence}]`
- `client_names`: any golf course or client names mentioned

Signal types:
- `feature_request` — client asks for something that doesn't exist
- `bug_report` — something isn't working as expected
- `competitor_mention` — reference to competing products
- `churn_signal` — dissatisfaction, evaluating alternatives
- `commitment` — someone promises to do something
- `positive_feedback` — client expresses satisfaction
- `pricing_discussion` — conversation about pricing or costs
- `onboarding_issue` — problems during client setup or training

### Cost Estimate

- Sonnet: ~$3/M input tokens, ~$15/M output tokens
- Average transcript: ~18K chars ≈ ~5K tokens
- With chunking (15-min chunks), a 40-min meeting = ~3 API calls
- Per meeting: ~$0.02-0.05
- 18 existing transcripts: ~$0.50-1.00

### Existing Code

The pipeline is already built (`Pipeline.Processor`, `Extractor`, `Chunker`, `Merger`). Changes needed:
- Update `Extractor` prompt to include people roster
- Add `role` and `context` to people schema
- Create `mix hub.process` task
- Reconnect the API key in config

## 3. Updated Document Detail Page

Already structured correctly in `document_live.ex`. With processed data:

```
┌──────────────────────────────────────────────┐
│ ← Back to Feed                               │
│                                              │
│ Standup: Web/Backend                         │
│ jarrette, weston · Apr 6, 2026              │
│                                              │
│ ┌─ Summary ────────────────────────────────┐ │
│ │ Discussed trade time discount bug...     │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ ┌─ Signals ────────────────────────────────┐ │
│ │ 🔴 Bug: Trade time discounts not applied │ │
│ │ 💬 Commitment: Weston to check MCG       │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ ┌─ Action Items ───────────────────────────┐ │
│ │ • Weston will investigate Card Connect   │ │
│ │ • Check if Mount Road has online booking │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ ┌─ Full Transcript ────────────────────────┐ │
│ │ (color-coded speaker bubbles)            │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

No UI changes needed — `document_live.ex` already renders summary, signals, and action items when `processed_document` exists.

## 4. Semantic Search (! prefix)

### UX

Same search box, two modes:
- Normal typing → instant Postgres FTS (existing behavior)
- `!` prefix → AI-powered semantic search across all conversations

Example: `!what problems have clients reported with tee time booking?`

### Backend — Embeddings

**pgvector extension** in Postgres (no new infrastructure):

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

**New table: `transcript_chunks`**

```sql
CREATE TABLE transcript_chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  raw_document_id uuid REFERENCES raw_documents(id) ON DELETE CASCADE,
  content text NOT NULL,
  speaker text,
  chunk_index integer NOT NULL,
  start_ms integer,
  end_ms integer,
  embedding vector(1536),
  inserted_at timestamp NOT NULL DEFAULT now()
);

CREATE INDEX transcript_chunks_embedding_idx
  ON transcript_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

**Chunking strategy:**
- Split each transcript into ~500-token chunks with 50-token overlap
- Preserve speaker attribution per chunk
- Store start/end timestamps for linking back to transcript position

**Embedding generation:**
- Use Anthropic's Voyage API or OpenAI's embedding endpoint (cheaper for embeddings)
- Run as a mix task: `mix hub.embed` — generates embeddings for all un-embedded chunks
- ~$0.01 per transcript for embedding generation

### Backend — Query Flow

1. User types `!what are the main client complaints?`
2. Strip `!` prefix, embed the question
3. Query pgvector for top 20 most similar chunks (cosine similarity)
4. Build a prompt with those chunks as context + the question
5. Send to Claude Sonnet
6. Stream the response back to the LiveView

### UI — AI Answer

When `!` query is active, the search results area shows:

```
┌──────────────────────────────────────────────┐
│ AI Answer                                    │
│                                              │
│ Based on conversations from the past month,  │
│ the main client complaints are:              │
│                                              │
│ 1. Trade time discounts not being applied    │
│    correctly in the booking flow [1]         │
│ 2. Online booking disabled at Mount Road [2] │
│ 3. Logo quality issues on client portals [3] │
│                                              │
│ Sources:                                     │
│ [1] Standup: Web/Backend · Apr 6             │
│ [2] Zoom Meeting · Apr 1                     │
│ [3] Zoom Meeting · Apr 1                     │
└──────────────────────────────────────────────┘
```

- Response streams in (token by token via LiveView async)
- Source citations link to the actual transcripts
- Loading state shows "Thinking..." while Claude processes

### Cost per AI Query

- Embedding the question: negligible
- pgvector lookup: free (Postgres)
- Claude Sonnet with ~20 chunks context: ~$0.02-0.05 per query

## 5. Granola Removal

Remove all Granola-related code and data:
- Delete Granola seed data from the database
- Remove any Granola-specific ingestion code
- Clean up references in the codebase

## Implementation Order

1. **People management** — migration + page (needed before AI processing)
2. **Granola removal** — clean slate
3. **AI extraction pipeline** — reconnect with API key, update prompt with people context
4. **Embeddings + semantic search** — pgvector, chunking, `!` query flow

## Out of Scope

- Automatic processing on ingest (manual trigger for cost control)
- Real-time streaming from Anthropic API (can add later, start with full response)
- Embedding model selection (start with one, optimize later)
- Signal aggregation dashboards (just show per-document for now)
