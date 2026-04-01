# TenFore Hub — Design Spec

**Date:** 2026-04-01
**Author:** Igor Kuznetsov
**Status:** Draft

## Problem

Client conversations happen across the TenFore team but knowledge stays siloed. CSMs (Austin and others) talk to golf course clients daily. Developers, PMs, and leadership don't see what's discussed unless someone explicitly relays it. Feature requests, bug reports, competitor mentions, and churn signals sit in people's heads or disappear.

## Solution

TenFore Hub is an internal platform that ingests client conversations from corporate tools, processes them with AI, and surfaces actionable signals through a real-time dashboard. Starting with Zoom transcripts, expanding to Slack, email, GitHub, and Figma via a plugin system.

## Tech Stack

- **Runtime:** Elixir / Phoenix
- **UI:** Phoenix LiveView
- **Database:** PostgreSQL (via Ecto)
- **Job Queue:** Oban (Postgres-backed, no Redis)
- **AI:** Claude API via HTTP (Req/Finch)
- **Deployment:** Local (Docker Compose) → GCP Cloud Run

## Architecture

```
┌──────────────────────────────────────────────┐
│              LiveView Dashboard               │
│  (search, per-client timeline, signal feed)   │
└──────────────────┬───────────────────────────┘
                   │ PubSub
┌──────────────────┴───────────────────────────┐
│            Processing Pipeline                │
│  (Claude API: chunk → extract → summarize)    │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────┴───────────────────────────┐
│            Plugin Layer (GenServers)           │
│  Zoom: webhook receiver + backfill worker     │
│  (Slack, GitHub, etc. — later)                │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────┴───────────────────────────┐
│         PostgreSQL (Ecto + pgvector)          │
└──────────────────────────────────────────────┘
```

### Data Flow (Zoom)

1. Zoom fires `recording.transcript_completed` webhook → hits Phoenix endpoint
2. Endpoint validates `x-zm-signature`, enqueues Oban job
3. Job fetches VTT transcript via Zoom API, parses it, stores as `RawDocument`
4. Second Oban job sends transcript to Claude API, gets structured extraction, stores as `ProcessedDocument` + `Signal` records
5. PubSub broadcasts to LiveView — dashboard updates in real-time

## Plugin System

Each plugin implements a behaviour:

```elixir
defmodule Hub.Plugin do
  @callback name() :: String.t()
  @callback setup(config :: map()) :: :ok | {:error, term()}
  @callback validate() :: :ok | {:error, term()}

  # Webhook-based plugins
  @callback handle_webhook(event :: String.t(), payload :: map()) ::
    {:ok, [RawDocument.t()]} | {:error, term()}

  # For backfill / polling-based plugins
  @callback fetch_since(since :: DateTime.t()) ::
    {:ok, [RawDocument.t()]} | {:error, term()}
end
```

### Per Plugin

- **GenServer** for lifecycle — holds auth state (OAuth tokens), handles refresh on a timer, reports health
- **Phoenix route scope** for webhooks (`/webhooks/zoom`, `/webhooks/slack`, etc.)
- **Oban workers** for async processing

### Zoom Plugin Components

- `Hub.Plugins.Zoom.Auth` — GenServer holding and refreshing S2S OAuth token (every 55 min)
- `Hub.Plugins.Zoom.WebhookController` — receives webhook, validates signature, dispatches Oban job
- `Hub.Plugins.Zoom.FetchWorker` — Oban job: downloads VTT, parses, stores `RawDocument`
- `Hub.Plugins.Zoom.Parser` — converts VTT to structured segments (speaker, timestamp, text)

### Plugin Registration

Explicit in the supervision tree:

```elixir
# application.ex
children = [
  Hub.Repo,
  {Oban, oban_config()},
  Hub.Plugins.Zoom.Auth,
  # Hub.Plugins.Slack.Auth,
  HubWeb.Endpoint
]
```

## Data Model

### raw_documents

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| source | string | "zoom", "slack", etc. |
| source_id | string | Zoom meeting UUID |
| content | text | Full transcript text |
| segments | jsonb | Parsed VTT: `[{index, start_ms, end_ms, speaker, text}]` |
| participants | jsonb | List of names/emails |
| metadata | jsonb | Source-specific: topic, duration, host, etc. |
| ingested_at | utc_datetime | |

Unique index on `{source, source_id}`.

### processed_documents

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| raw_document_id | uuid | FK → raw_documents |
| summary | text | AI-generated summary |
| action_items | jsonb | `[{text, assignee, due_date}]` |
| model | string | Claude model used |
| prompt_version | string | Track extraction prompt changes |
| processed_at | utc_datetime | |

### signals

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| processed_document_id | uuid | FK → processed_documents |
| type | string | feature_request, bug_report, competitor_mention, churn_signal, commitment, positive_feedback |
| content | text | Quote or paraphrase |
| speaker | string | Who said it |
| confidence | float | AI confidence in classification |
| metadata | jsonb | Type-specific data |

Index on `type`.

### clients

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| name | string | "Sawyer Creek", "Pine Valley" |
| aliases | jsonb | Alternate names |
| metadata | jsonb | |

### document_clients (join table)

| Column | Type | Notes |
|--------|------|-------|
| raw_document_id | uuid | FK → raw_documents |
| client_id | uuid | FK → clients |

## AI Processing Pipeline

Triggered by Oban job when a `RawDocument` is stored.

### Step 1: Chunking

Long transcripts (1hr+) split into ~15 minute chunks at speaker turn boundaries. Short meetings (<30 min) processed as-is.

### Step 2: Extraction

Each chunk sent to Claude API with structured prompt:

```
You are analyzing a transcript from a client conversation at TenFore,
a golf course management software company.

Participants: {participants}
Meeting topic: {topic}
Date: {date}

Extract the following as JSON:
- summary: 2-3 sentence summary of this segment
- action_items: [{text, assignee (if mentioned), due_date (if mentioned)}]
- signals: [{type, content (exact quote or close paraphrase), speaker, confidence}]
- client_names: any golf course / client names mentioned

Signal types:
- feature_request: client asks for something that doesn't exist
- bug_report: something isn't working as expected
- competitor_mention: reference to competing products
- churn_signal: dissatisfaction, evaluating alternatives
- commitment: someone promises to do something by a date
- positive_feedback: client expresses satisfaction

Transcript:
{chunk}
```

Uses Claude structured output (tool use / JSON mode) for guaranteed parseable responses.

### Step 3: Merge

If chunked: deduplicate signals, combine summaries, aggregate action items.

### Step 4: Client Resolution

Match extracted `client_names` against `clients` table with fuzzy matching on aliases. New client names auto-create records for later review/merge in UI.

### Step 5: Store & Broadcast

Save `ProcessedDocument` + `Signal` records, link to clients, broadcast via PubSub to LiveView.

All steps in a single Oban job with retries and backoff. Raw documents always preserved for reprocessing with updated prompts.

## LiveView Dashboard

### Feed (landing page)

- Reverse-chronological list of processed transcripts
- Cards: date, topic, participants, client name, summary, signal badges (colored by type)
- Click to expand: full transcript with signals highlighted inline
- Filter bar: signal type, client, date range, participant
- Real-time updates via PubSub

### Client View

- Select client → timeline of all their conversations
- Aggregated stats: total calls, signal breakdown
- Useful for call prep

### Search

- Full-text search across transcripts and signals
- Filters stack with search (e.g. "kiosk" + "feature_request")

## Explicitly Deferred (not v1)

- User accounts / auth (solo user for now)
- Analytics / charts / trend dashboards
- "Ask the transcripts" RAG chat
- Email / Slack notification digests
- pgvector embeddings / semantic search
- Plugins beyond Zoom
