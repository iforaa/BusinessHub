# TenFore Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Phoenix LiveView application that ingests Zoom meeting transcripts via webhooks, extracts actionable signals with Claude AI, and surfaces them in a real-time dashboard.

**Architecture:** Plugin-based ingestion (starting with Zoom) feeds raw documents into an AI processing pipeline (chunking → Claude extraction → merge). Results stored in PostgreSQL and pushed to a LiveView dashboard via PubSub. Oban handles async job processing.

**Tech Stack:** Elixir, Phoenix, LiveView, Ecto, PostgreSQL, Oban, Req (HTTP client), Claude API

---

## File Structure

```
hub/
├── lib/
│   ├── hub/
│   │   ├── application.ex                    # Supervision tree
│   │   ├── repo.ex                           # Ecto repo
│   │   ├── documents/
│   │   │   ├── raw_document.ex               # Ecto schema + changeset
│   │   │   ├── processed_document.ex         # Ecto schema + changeset
│   │   │   └── signal.ex                     # Ecto schema + changeset
│   │   ├── clients/
│   │   │   ├── client.ex                     # Ecto schema + changeset
│   │   │   └── document_client.ex            # Join schema
│   │   │   └── resolver.ex                   # Fuzzy match client names
│   │   ├── plugin.ex                         # Plugin behaviour definition
│   │   ├── plugins/
│   │   │   └── zoom/
│   │   │       ├── auth.ex                   # GenServer: S2S OAuth token management
│   │   │       ├── client.ex                 # HTTP calls to Zoom API
│   │   │       ├── parser.ex                 # VTT → structured segments
│   │   │       ├── fetch_worker.ex           # Oban job: download + store transcript
│   │   │       └── backfill.ex               # One-off: pull historical transcripts
│   │   ├── pipeline/
│   │   │   ├── processor.ex                  # Oban job: orchestrates extraction
│   │   │   ├── chunker.ex                    # Split long transcripts
│   │   │   ├── extractor.ex                  # Claude API call + prompt
│   │   │   └── merger.ex                     # Combine chunked results
│   │   └── claude/
│   │       └── client.ex                     # HTTP wrapper for Claude API
│   ├── hub_web/
│   │   ├── router.ex                         # Routes: webhooks + LiveView
│   │   ├── controllers/
│   │   │   └── zoom_webhook_controller.ex    # Webhook endpoint
│   │   ├── live/
│   │   │   ├── feed_live.ex                  # Main feed page
│   │   │   ├── document_live.ex              # Single document detail
│   │   │   ├── client_live.ex                # Per-client timeline
│   │   │   └── search_live.ex                # Search page
│   │   └── components/
│   │       ├── signal_badge.ex               # Signal type badge component
│   │       └── document_card.ex              # Transcript card component
├── test/
│   ├── hub/
│   │   ├── documents/
│   │   │   └── raw_document_test.exs
│   │   ├── clients/
│   │   │   └── resolver_test.exs
│   │   ├── plugins/zoom/
│   │   │   ├── auth_test.exs
│   │   │   ├── parser_test.exs
│   │   │   └── fetch_worker_test.exs
│   │   ├── pipeline/
│   │   │   ├── chunker_test.exs
│   │   │   ├── extractor_test.exs
│   │   │   ├── merger_test.exs
│   │   │   └── processor_test.exs
│   │   └── claude/
│   │       └── client_test.exs
│   ├── hub_web/
│   │   ├── controllers/
│   │   │   └── zoom_webhook_controller_test.exs
│   │   └── live/
│   │       ├── feed_live_test.exs
│   │       └── search_live_test.exs
│   ├── support/
│   │   └── fixtures/
│   │       ├── sample.vtt                    # Real-ish VTT for tests
│   │       └── zoom_webhook_payload.json     # Sample webhook payload
├── priv/
│   └── repo/migrations/
│       ├── *_create_raw_documents.exs
│       ├── *_create_processed_documents.exs
│       ├── *_create_signals.exs
│       ├── *_create_clients.exs
│       └── *_create_document_clients.exs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs                           # Zoom creds, Claude API key
└── docker-compose.yml                        # PostgreSQL for local dev
```

---

### Task 1: Phoenix Project Scaffold + PostgreSQL

**Files:**
- Create: entire Phoenix project via `mix phx.new`
- Create: `docker-compose.yml`
- Modify: `config/dev.exs`, `config/test.exs`, `config/runtime.exs`
- Modify: `mix.exs` (add deps)

- [ ] **Step 1: Generate Phoenix project**

```bash
mix phx.new hub --module Hub --app hub
```

Accept defaults (yes to install deps). This creates the full Phoenix project with LiveView included by default.

- [ ] **Step 2: Add docker-compose.yml for PostgreSQL**

Create `docker-compose.yml` in project root:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: hub_dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

- [ ] **Step 3: Start PostgreSQL and verify**

```bash
docker compose up -d
```

Expected: PostgreSQL running on localhost:5432.

- [ ] **Step 4: Add dependencies to mix.exs**

Add to the `deps` function in `mix.exs`:

```elixir
{:oban, "~> 2.18"},
{:req, "~> 0.5"},
```

Phoenix already includes ecto_sql, postgrex, jason, and phoenix_live_view.

- [ ] **Step 5: Install deps and verify**

```bash
mix deps.get
```

Expected: all deps fetched successfully.

- [ ] **Step 6: Configure Oban in config/config.exs**

Add to `config/config.exs`:

```elixir
config :hub, Oban,
  repo: Hub.Repo,
  queues: [
    zoom: 5,
    pipeline: 3
  ]
```

- [ ] **Step 7: Add runtime config placeholders**

Add to `config/runtime.exs`:

```elixir
config :hub, :zoom,
  account_id: System.get_env("ZOOM_ACCOUNT_ID"),
  client_id: System.get_env("ZOOM_CLIENT_ID"),
  client_secret: System.get_env("ZOOM_CLIENT_SECRET"),
  webhook_secret: System.get_env("ZOOM_WEBHOOK_SECRET")

config :hub, :claude,
  api_key: System.get_env("CLAUDE_API_KEY"),
  model: System.get_env("CLAUDE_MODEL") || "claude-sonnet-4-20250514"
```

- [ ] **Step 8: Add Oban to supervision tree**

In `lib/hub/application.ex`, add `{Oban, Application.fetch_env!(:hub, Oban)}` to the children list, after `Hub.Repo`.

- [ ] **Step 9: Create database and verify**

```bash
mix ecto.create
```

Expected: database `hub_dev` created.

- [ ] **Step 10: Run existing tests**

```bash
mix test
```

Expected: default Phoenix tests pass.

- [ ] **Step 11: Commit**

```
scaffold phoenix project with oban and postgres
```

---

### Task 2: Database Schema — Raw Documents

**Files:**
- Create: `priv/repo/migrations/*_create_raw_documents.exs`
- Create: `lib/hub/documents/raw_document.ex`
- Create: `test/hub/documents/raw_document_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub/documents/raw_document_test.exs`:

```elixir
defmodule Hub.Documents.RawDocumentTest do
  use Hub.DataCase

  alias Hub.Documents.RawDocument

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        source: "zoom",
        source_id: "abc-123",
        content: "Full transcript text here",
        segments: [%{"index" => 1, "start_ms" => 0, "end_ms" => 5000, "speaker" => "Igor", "text" => "Hello"}],
        participants: ["Igor Kuznetsov", "Austin Smith"],
        metadata: %{"topic" => "Weekly standup", "duration_minutes" => 30}
      }

      changeset = RawDocument.changeset(%RawDocument{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = RawDocument.changeset(%RawDocument{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).source
      assert "can't be blank" in errors_on(changeset).source_id
      assert "can't be blank" in errors_on(changeset).content
    end

    test "enforces unique source + source_id" do
      attrs = %{source: "zoom", source_id: "abc-123", content: "text", segments: [], participants: [], metadata: %{}}
      {:ok, _} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()
      {:error, changeset} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()
      assert "has already been taken" in errors_on(changeset).source_id
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub/documents/raw_document_test.exs
```

Expected: compilation error — `Hub.Documents.RawDocument` not found.

- [ ] **Step 3: Generate migration**

```bash
mix ecto.gen.migration create_raw_documents
```

Fill the migration:

```elixir
defmodule Hub.Repo.Migrations.CreateRawDocuments do
  use Ecto.Migration

  def change do
    create table(:raw_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string, null: false
      add :source_id, :string, null: false
      add :content, :text, null: false
      add :segments, :jsonb, default: "[]"
      add :participants, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"
      add :ingested_at, :utc_datetime_usec, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:raw_documents, [:source, :source_id])
    create index(:raw_documents, [:source])
    create index(:raw_documents, [:ingested_at])
  end
end
```

- [ ] **Step 4: Create the schema module**

Create `lib/hub/documents/raw_document.ex`:

```elixir
defmodule Hub.Documents.RawDocument do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "raw_documents" do
    field :source, :string
    field :source_id, :string
    field :content, :string
    field :segments, {:array, :map}, default: []
    field :participants, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :ingested_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(raw_document, attrs) do
    raw_document
    |> cast(attrs, [:source, :source_id, :content, :segments, :participants, :metadata, :ingested_at])
    |> validate_required([:source, :source_id, :content])
    |> unique_constraint(:source_id, name: :raw_documents_source_source_id_index)
  end
end
```

- [ ] **Step 5: Run migration**

```bash
mix ecto.migrate
```

Expected: migration runs successfully.

- [ ] **Step 6: Run tests**

```bash
mix test test/hub/documents/raw_document_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 7: Commit**

```
add raw_documents schema and migration
```

---

### Task 3: Database Schema — Processed Documents, Signals, Clients

**Files:**
- Create: `priv/repo/migrations/*_create_processed_documents.exs`
- Create: `priv/repo/migrations/*_create_signals.exs`
- Create: `priv/repo/migrations/*_create_clients.exs`
- Create: `priv/repo/migrations/*_create_document_clients.exs`
- Create: `lib/hub/documents/processed_document.ex`
- Create: `lib/hub/documents/signal.ex`
- Create: `lib/hub/clients/client.ex`
- Create: `lib/hub/clients/document_client.ex`

- [ ] **Step 1: Generate all migrations**

```bash
mix ecto.gen.migration create_processed_documents
mix ecto.gen.migration create_signals
mix ecto.gen.migration create_clients
mix ecto.gen.migration create_document_clients
```

- [ ] **Step 2: Fill processed_documents migration**

```elixir
defmodule Hub.Repo.Migrations.CreateProcessedDocuments do
  use Ecto.Migration

  def change do
    create table(:processed_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :summary, :text
      add :action_items, :jsonb, default: "[]"
      add :model, :string
      add :prompt_version, :string
      add :processed_at, :utc_datetime_usec, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime_usec)
    end

    create index(:processed_documents, [:raw_document_id])
  end
end
```

- [ ] **Step 3: Fill signals migration**

```elixir
defmodule Hub.Repo.Migrations.CreateSignals do
  use Ecto.Migration

  def change do
    create table(:signals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :processed_document_id, references(:processed_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :content, :text, null: false
      add :speaker, :string
      add :confidence, :float
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:signals, [:type])
    create index(:signals, [:processed_document_id])
  end
end
```

- [ ] **Step 4: Fill clients migration**

```elixir
defmodule Hub.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :aliases, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:clients, [:name])
  end
end
```

- [ ] **Step 5: Fill document_clients migration**

```elixir
defmodule Hub.Repo.Migrations.CreateDocumentClients do
  use Ecto.Migration

  def change do
    create table(:document_clients, primary_key: false) do
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:document_clients, [:raw_document_id, :client_id])
    create index(:document_clients, [:client_id])
  end
end
```

- [ ] **Step 6: Create schema modules**

Create `lib/hub/documents/processed_document.ex`:

```elixir
defmodule Hub.Documents.ProcessedDocument do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.{RawDocument, Signal}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "processed_documents" do
    belongs_to :raw_document, RawDocument
    has_many :signals, Signal

    field :summary, :string
    field :action_items, {:array, :map}, default: []
    field :model, :string
    field :prompt_version, :string
    field :processed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(processed_document, attrs) do
    processed_document
    |> cast(attrs, [:raw_document_id, :summary, :action_items, :model, :prompt_version, :processed_at])
    |> validate_required([:raw_document_id])
    |> foreign_key_constraint(:raw_document_id)
  end
end
```

Create `lib/hub/documents/signal.ex`:

```elixir
defmodule Hub.Documents.Signal do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.ProcessedDocument

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @signal_types ~w(feature_request bug_report competitor_mention churn_signal commitment positive_feedback)

  schema "signals" do
    belongs_to :processed_document, ProcessedDocument

    field :type, :string
    field :content, :string
    field :speaker, :string
    field :confidence, :float
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, [:processed_document_id, :type, :content, :speaker, :confidence, :metadata])
    |> validate_required([:processed_document_id, :type, :content])
    |> validate_inclusion(:type, @signal_types)
    |> foreign_key_constraint(:processed_document_id)
  end

  def signal_types, do: @signal_types
end
```

Create `lib/hub/clients/client.ex`:

```elixir
defmodule Hub.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.RawDocument

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clients" do
    field :name, :string
    field :aliases, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    many_to_many :raw_documents, RawDocument, join_through: "document_clients"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :aliases, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
```

Create `lib/hub/clients/document_client.ex`:

```elixir
defmodule Hub.Clients.DocumentClient do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :binary_id

  schema "document_clients" do
    belongs_to :raw_document, Hub.Documents.RawDocument
    belongs_to :client, Hub.Clients.Client
  end
end
```

- [ ] **Step 7: Run migrations**

```bash
mix ecto.migrate
```

Expected: 4 migrations run successfully.

- [ ] **Step 8: Run all tests**

```bash
mix test
```

Expected: all tests pass (including Task 2 tests).

- [ ] **Step 9: Commit**

```
add processed_documents, signals, clients schemas
```

---

### Task 4: VTT Parser

**Files:**
- Create: `lib/hub/plugins/zoom/parser.ex`
- Create: `test/hub/plugins/zoom/parser_test.exs`
- Create: `test/support/fixtures/sample.vtt`

- [ ] **Step 1: Create test fixture**

Create `test/support/fixtures/sample.vtt`:

```
WEBVTT

1
00:00:03.450 --> 00:00:08.120
Igor Kuznetsov: Good morning everyone, let's talk about the kiosk update.

2
00:00:08.900 --> 00:00:15.340
Austin Smith: Sure. So Sawyer Creek called yesterday about the Apple Pay issue.

3
00:00:16.000 --> 00:00:22.500
Austin Smith: They said their members keep asking for it. It's becoming a dealbreaker.

4
00:00:23.100 --> 00:00:30.800
Igor Kuznetsov: Got it. I'll look into the Apple Pay integration this sprint. Any other feedback?

5
00:00:31.500 --> 00:00:38.200
Austin Smith: Pine Valley mentioned that the subcourse switcher is confusing. They want it simplified.
```

- [ ] **Step 2: Write the test**

Create `test/hub/plugins/zoom/parser_test.exs`:

```elixir
defmodule Hub.Plugins.Zoom.ParserTest do
  use ExUnit.Case

  alias Hub.Plugins.Zoom.Parser

  @fixture_path "test/support/fixtures/sample.vtt"

  describe "parse_vtt/1" do
    test "parses VTT content into structured segments" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)

      assert length(segments) == 5

      first = Enum.at(segments, 0)
      assert first.index == 1
      assert first.start_ms == 3_450
      assert first.end_ms == 8_120
      assert first.speaker == "Igor Kuznetsov"
      assert first.text == "Good morning everyone, let's talk about the kiosk update."

      second = Enum.at(segments, 1)
      assert second.speaker == "Austin Smith"
      assert second.start_ms == 8_900
    end

    test "extracts unique participants" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)
      participants = Parser.extract_participants(segments)

      assert participants == ["Austin Smith", "Igor Kuznetsov"]
    end

    test "concatenates full text" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)
      full_text = Parser.full_text(segments)

      assert full_text =~ "Good morning everyone"
      assert full_text =~ "subcourse switcher is confusing"
    end

    test "returns error for invalid VTT" do
      assert {:error, :invalid_vtt} = Parser.parse_vtt("")
      assert {:error, :invalid_vtt} = Parser.parse_vtt("not a vtt file")
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
mix test test/hub/plugins/zoom/parser_test.exs
```

Expected: compilation error — `Hub.Plugins.Zoom.Parser` not found.

- [ ] **Step 4: Implement the parser**

Create `lib/hub/plugins/zoom/parser.ex`:

```elixir
defmodule Hub.Plugins.Zoom.Parser do
  @moduledoc """
  Parses Zoom VTT transcript files into structured segments.
  """

  defmodule Segment do
    @derive Jason.Encoder
    defstruct [:index, :start_ms, :end_ms, :speaker, :text]

    @type t :: %__MODULE__{
      index: integer(),
      start_ms: integer(),
      end_ms: integer(),
      speaker: String.t(),
      text: String.t()
    }
  end

  @timestamp_pattern ~r/(\d{2}):(\d{2}):(\d{2})\.(\d{3})/

  def parse_vtt(content) when is_binary(content) do
    content = String.trim(content)

    if content == "" or not String.starts_with?(content, "WEBVTT") do
      {:error, :invalid_vtt}
    else
      segments =
        content
        |> String.split(~r/\n\n+/)
        |> Enum.drop(1)
        |> Enum.map(&parse_block/1)
        |> Enum.reject(&is_nil/1)

      {:ok, segments}
    end
  end

  def extract_participants(segments) do
    segments
    |> Enum.map(& &1.speaker)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def full_text(segments) do
    segments
    |> Enum.map(fn seg -> "#{seg.speaker}: #{seg.text}" end)
    |> Enum.join("\n")
  end

  defp parse_block(block) do
    lines = String.split(block, "\n", trim: true)

    case lines do
      [index_str, timestamp_line | text_lines] ->
        with {index, ""} <- Integer.parse(String.trim(index_str)),
             {start_ms, end_ms} <- parse_timestamps(timestamp_line),
             {speaker, text} <- parse_speaker_text(Enum.join(text_lines, " ")) do
          %Segment{
            index: index,
            start_ms: start_ms,
            end_ms: end_ms,
            speaker: speaker,
            text: text
          }
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_timestamps(line) do
    case Regex.scan(@timestamp_pattern, line) do
      [start_match, end_match] ->
        {timestamp_to_ms(start_match), timestamp_to_ms(end_match)}

      _ ->
        nil
    end
  end

  defp timestamp_to_ms([_full, hours, minutes, seconds, milliseconds]) do
    String.to_integer(hours) * 3_600_000 +
      String.to_integer(minutes) * 60_000 +
      String.to_integer(seconds) * 1_000 +
      String.to_integer(milliseconds)
  end

  defp parse_speaker_text(text) do
    case String.split(text, ": ", parts: 2) do
      [speaker, content] -> {speaker, content}
      [content] -> {"Unknown", content}
    end
  end
end
```

- [ ] **Step 5: Run tests**

```bash
mix test test/hub/plugins/zoom/parser_test.exs
```

Expected: 4 tests, 0 failures.

- [ ] **Step 6: Commit**

```
add VTT parser for zoom transcripts
```

---

### Task 5: Zoom S2S OAuth Auth GenServer

**Files:**
- Create: `lib/hub/plugins/zoom/auth.ex`
- Create: `test/hub/plugins/zoom/auth_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub/plugins/zoom/auth_test.exs`:

```elixir
defmodule Hub.Plugins.Zoom.AuthTest do
  use ExUnit.Case

  alias Hub.Plugins.Zoom.Auth

  describe "token management" do
    test "get_token/0 returns error when not configured" do
      # Auth GenServer won't be started in test env without config.
      # Test the token fetch logic directly.
      assert {:error, _reason} = Auth.fetch_token(%{
        account_id: "fake",
        client_id: "fake",
        client_secret: "fake"
      })
    end

    test "build_auth_header/2 encodes credentials correctly" do
      header = Auth.build_auth_header("my_client_id", "my_client_secret")
      expected = Base.encode64("my_client_id:my_client_secret")
      assert header == "Basic #{expected}"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub/plugins/zoom/auth_test.exs
```

Expected: compilation error — `Hub.Plugins.Zoom.Auth` not found.

- [ ] **Step 3: Implement the Auth GenServer**

Create `lib/hub/plugins/zoom/auth.ex`:

```elixir
defmodule Hub.Plugins.Zoom.Auth do
  @moduledoc """
  GenServer that manages Zoom Server-to-Server OAuth tokens.
  Automatically refreshes the token before expiry.
  """

  use GenServer
  require Logger

  @token_url "https://zoom.us/oauth/token"
  @refresh_buffer_ms 5 * 60 * 1000

  # Client API

  def start_link(opts \\ []) do
    config = opts[:config] || zoom_config()
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def get_token do
    GenServer.call(__MODULE__, :get_token)
  end

  def build_auth_header(client_id, client_secret) do
    encoded = Base.encode64("#{client_id}:#{client_secret}")
    "Basic #{encoded}"
  end

  # Server callbacks

  @impl true
  def init(config) do
    state = %{
      config: config,
      token: nil,
      expires_at: nil
    }

    {:ok, state, {:continue, :fetch_token}}
  end

  @impl true
  def handle_continue(:fetch_token, state) do
    case fetch_token(state.config) do
      {:ok, token, expires_in} ->
        schedule_refresh(expires_in)
        {:noreply, %{state | token: token, expires_at: System.monotonic_time(:millisecond) + expires_in * 1000}}

      {:error, reason} ->
        Logger.error("Failed to fetch Zoom token: #{inspect(reason)}. Retrying in 30s.")
        Process.send_after(self(), :refresh_token, 30_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_token, _from, %{token: nil} = state) do
    {:reply, {:error, :no_token}, state}
  end

  def handle_call(:get_token, _from, state) do
    {:reply, {:ok, state.token}, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    {:noreply, state, {:continue, :fetch_token}}
  end

  # Token fetch

  def fetch_token(config) do
    auth_header = build_auth_header(config.client_id, config.client_secret)

    case Req.post(@token_url,
      params: [grant_type: "account_credentials", account_id: config.account_id],
      headers: [{"authorization", auth_header}]
    ) do
      {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        Logger.info("Zoom OAuth token fetched successfully, expires in #{expires_in}s")
        {:ok, token, expires_in}

      {:ok, %{status: status, body: body}} ->
        {:error, "Zoom token request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_refresh(expires_in_seconds) do
    refresh_in = max((expires_in_seconds * 1000) - @refresh_buffer_ms, 10_000)
    Process.send_after(self(), :refresh_token, refresh_in)
  end

  defp zoom_config do
    config = Application.fetch_env!(:hub, :zoom)
    %{
      account_id: config[:account_id],
      client_id: config[:client_id],
      client_secret: config[:client_secret]
    }
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/hub/plugins/zoom/auth_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```
add zoom S2S oauth auth genserver
```

---

### Task 6: Zoom API Client + Webhook Controller

**Files:**
- Create: `lib/hub/plugins/zoom/client.ex`
- Create: `lib/hub_web/controllers/zoom_webhook_controller.ex`
- Create: `test/hub_web/controllers/zoom_webhook_controller_test.exs`
- Create: `test/support/fixtures/zoom_webhook_payload.json`
- Modify: `lib/hub_web/router.ex`

- [ ] **Step 1: Create webhook payload fixture**

Create `test/support/fixtures/zoom_webhook_payload.json`:

```json
{
  "event": "recording.transcript_completed",
  "event_ts": 1711800000000,
  "payload": {
    "account_id": "ABCDEF",
    "object": {
      "uuid": "abc123==",
      "id": 98765432,
      "host_id": "user-id-123",
      "host_email": "host@tenfore.com",
      "topic": "Sawyer Creek Weekly Check-in",
      "start_time": "2026-03-30T14:00:00Z",
      "recording_files": [
        {
          "id": "transcript-file-id",
          "recording_type": "audio_transcript",
          "file_type": "TRANSCRIPT",
          "file_extension": "VTT",
          "download_url": "https://zoom.us/rec/download/fake-url",
          "status": "completed"
        }
      ]
    }
  }
}
```

- [ ] **Step 2: Write the webhook controller test**

Create `test/hub_web/controllers/zoom_webhook_controller_test.exs`:

```elixir
defmodule HubWeb.ZoomWebhookControllerTest do
  use HubWeb.ConnCase

  @fixture_path "test/support/fixtures/zoom_webhook_payload.json"

  describe "POST /webhooks/zoom" do
    test "returns 200 and enqueues job for valid transcript_completed event", %{conn: conn} do
      payload = @fixture_path |> File.read!() |> Jason.decode!()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert_enqueued(worker: Hub.Plugins.Zoom.FetchWorker)
    end

    test "responds to Zoom URL validation challenge", %{conn: conn} do
      payload = %{
        "event" => "endpoint.url_validation",
        "payload" => %{
          "plainToken" => "test-token-123"
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      response = json_response(conn, 200)
      assert response["plainToken"] == "test-token-123"
      assert is_binary(response["encryptedToken"])
    end

    test "returns 400 for unknown event", %{conn: conn} do
      payload = %{"event" => "unknown.event", "payload" => %{}}

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      assert json_response(conn, 400) == %{"error" => "unhandled event"}
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
mix test test/hub_web/controllers/zoom_webhook_controller_test.exs
```

Expected: compilation error or route not found.

- [ ] **Step 4: Create the Zoom API client**

Create `lib/hub/plugins/zoom/client.ex`:

```elixir
defmodule Hub.Plugins.Zoom.Client do
  @moduledoc """
  HTTP client for Zoom API — fetches recordings and downloads transcripts.
  """

  alias Hub.Plugins.Zoom.Auth

  @base_url "https://api.zoom.us/v2"

  def download_transcript(download_url) do
    with {:ok, token} <- Auth.get_token() do
      case Req.get(download_url, headers: [{"authorization", "Bearer #{token}"}], redirect: true) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status}} -> {:error, "Download failed with status #{status}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_meeting_recordings(meeting_id) do
    with {:ok, token} <- Auth.get_token() do
      # Double-encode meeting IDs that contain / or //
      encoded_id = double_encode_uuid(meeting_id)

      case Req.get("#{@base_url}/meetings/#{encoded_id}/recordings",
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "API returned #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_user_recordings(user_id, from_date, to_date) do
    with {:ok, token} <- Auth.get_token() do
      case Req.get("#{@base_url}/users/#{user_id}/recordings",
        params: [from: from_date, to: to_date],
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "API returned #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp double_encode_uuid(uuid) do
    if String.contains?(uuid, "/") do
      URI.encode(URI.encode(uuid, &URI.char_unreserved?/1), &URI.char_unreserved?/1)
    else
      uuid
    end
  end
end
```

- [ ] **Step 5: Create the webhook controller**

Create `lib/hub_web/controllers/zoom_webhook_controller.ex`:

```elixir
defmodule HubWeb.ZoomWebhookController do
  use HubWeb, :controller

  require Logger

  def handle(conn, %{"event" => "endpoint.url_validation", "payload" => %{"plainToken" => token}}) do
    secret = zoom_webhook_secret()
    encrypted = :crypto.mac(:hmac, :sha256, secret, token) |> Base.encode16(case: :lower)

    json(conn, %{plainToken: token, encryptedToken: encrypted})
  end

  def handle(conn, %{"event" => "recording.transcript_completed", "payload" => %{"object" => object}}) do
    meeting_uuid = object["uuid"]
    topic = object["topic"] || "Untitled Meeting"
    host_email = object["host_email"]
    start_time = object["start_time"]

    transcript_files =
      (object["recording_files"] || [])
      |> Enum.filter(fn f -> f["file_type"] == "TRANSCRIPT" end)

    case transcript_files do
      [] ->
        Logger.warning("Transcript completed webhook received but no transcript files found for meeting #{meeting_uuid}")
        json(conn, %{status: "ok", message: "no transcript files"})

      files ->
        Enum.each(files, fn file ->
          %{
            meeting_uuid: meeting_uuid,
            topic: topic,
            host_email: host_email,
            start_time: start_time,
            download_url: file["download_url"],
            participants: object["participant_audio_files"] || []
          }
          |> Hub.Plugins.Zoom.FetchWorker.new()
          |> Oban.insert!()
        end)

        Logger.info("Enqueued #{length(files)} transcript fetch job(s) for meeting #{meeting_uuid}")
        json(conn, %{status: "ok"})
    end
  end

  def handle(conn, %{"event" => event}) do
    Logger.debug("Ignoring Zoom webhook event: #{event}")
    conn |> put_status(400) |> json(%{error: "unhandled event"})
  end

  defp zoom_webhook_secret do
    Application.fetch_env!(:hub, :zoom)[:webhook_secret] || ""
  end
end
```

- [ ] **Step 6: Add route**

In `lib/hub_web/router.ex`, add a webhook scope (outside the browser pipeline):

```elixir
scope "/webhooks", HubWeb do
  pipe_through :api
  post "/zoom", ZoomWebhookController, :handle
end
```

- [ ] **Step 7: Add Oban testing config**

In `config/test.exs`, add:

```elixir
config :hub, Oban, testing: :inline
```

And in `test/support/conn_case.ex`, add to the `using` block:

```elixir
use Oban.Testing, repo: Hub.Repo
```

- [ ] **Step 8: Run tests**

```bash
mix test test/hub_web/controllers/zoom_webhook_controller_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 9: Commit**

```
add zoom webhook controller and API client
```

---

### Task 7: Zoom Fetch Worker (Oban Job)

**Files:**
- Create: `lib/hub/plugins/zoom/fetch_worker.ex`
- Create: `test/hub/plugins/zoom/fetch_worker_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub/plugins/zoom/fetch_worker_test.exs`:

```elixir
defmodule Hub.Plugins.Zoom.FetchWorkerTest do
  use Hub.DataCase
  use Oban.Testing, repo: Hub.Repo

  alias Hub.Plugins.Zoom.FetchWorker
  alias Hub.Documents.RawDocument

  @sample_vtt File.read!("test/support/fixtures/sample.vtt")

  describe "perform/1" do
    test "stores raw document from VTT content" do
      # Mock the Zoom API client by injecting VTT content directly
      args = %{
        "meeting_uuid" => "test-meeting-123",
        "topic" => "Client Check-in",
        "host_email" => "austin@tenfore.com",
        "start_time" => "2026-03-30T14:00:00Z",
        "download_url" => "https://fake.zoom.us/transcript",
        "vtt_content" => @sample_vtt
      }

      assert :ok = perform_job(FetchWorker, args)

      doc = Hub.Repo.get_by!(RawDocument, source_id: "test-meeting-123")
      assert doc.source == "zoom"
      assert doc.content =~ "Good morning everyone"
      assert length(doc.segments) == 5
      assert "Igor Kuznetsov" in doc.participants
      assert "Austin Smith" in doc.participants
      assert doc.metadata["topic"] == "Client Check-in"
    end

    test "skips if document already exists" do
      attrs = %{source: "zoom", source_id: "test-meeting-123", content: "existing", segments: [], participants: [], metadata: %{}}
      {:ok, _} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()

      args = %{
        "meeting_uuid" => "test-meeting-123",
        "topic" => "Client Check-in",
        "host_email" => "austin@tenfore.com",
        "start_time" => "2026-03-30T14:00:00Z",
        "download_url" => "https://fake.zoom.us/transcript",
        "vtt_content" => @sample_vtt
      }

      assert :ok = perform_job(FetchWorker, args)
      assert Hub.Repo.aggregate(RawDocument, :count) == 1
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub/plugins/zoom/fetch_worker_test.exs
```

Expected: compilation error — `Hub.Plugins.Zoom.FetchWorker` not found.

- [ ] **Step 3: Implement the fetch worker**

Create `lib/hub/plugins/zoom/fetch_worker.ex`:

```elixir
defmodule Hub.Plugins.Zoom.FetchWorker do
  @moduledoc """
  Oban worker that downloads a Zoom VTT transcript and stores it as a RawDocument.
  Enqueues a processing pipeline job on success.
  """

  use Oban.Worker, queue: :zoom, max_attempts: 3

  alias Hub.Documents.RawDocument
  alias Hub.Plugins.Zoom.{Client, Parser}
  alias Hub.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    meeting_uuid = args["meeting_uuid"]

    if Repo.get_by(RawDocument, source: "zoom", source_id: meeting_uuid) do
      Logger.info("Transcript for meeting #{meeting_uuid} already exists, skipping")
      :ok
    else
      with {:ok, vtt_content} <- fetch_vtt(args),
           {:ok, segments} <- Parser.parse_vtt(vtt_content),
           {:ok, raw_doc} <- store_document(args, segments, vtt_content) do
        Logger.info("Stored transcript for meeting #{meeting_uuid} (#{length(segments)} segments)")

        # Enqueue AI processing
        %{raw_document_id: raw_doc.id}
        |> Hub.Pipeline.Processor.new()
        |> Oban.insert!()

        :ok
      else
        {:error, reason} ->
          Logger.error("Failed to fetch transcript for meeting #{meeting_uuid}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp fetch_vtt(%{"vtt_content" => content}) when is_binary(content), do: {:ok, content}
  defp fetch_vtt(%{"download_url" => url}), do: Client.download_transcript(url)

  defp store_document(args, segments, vtt_content) do
    participants = Parser.extract_participants(segments)
    full_text = Parser.full_text(segments)

    segments_json = Enum.map(segments, fn seg ->
      %{
        "index" => seg.index,
        "start_ms" => seg.start_ms,
        "end_ms" => seg.end_ms,
        "speaker" => seg.speaker,
        "text" => seg.text
      }
    end)

    attrs = %{
      source: "zoom",
      source_id: args["meeting_uuid"],
      content: full_text,
      segments: segments_json,
      participants: participants,
      metadata: %{
        "topic" => args["topic"],
        "host_email" => args["host_email"],
        "start_time" => args["start_time"],
        "download_url" => args["download_url"]
      },
      ingested_at: DateTime.utc_now()
    }

    %RawDocument{}
    |> RawDocument.changeset(attrs)
    |> Repo.insert()
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/hub/plugins/zoom/fetch_worker_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```
add zoom fetch worker oban job
```

---

### Task 8: Claude API Client

**Files:**
- Create: `lib/hub/claude/client.ex`
- Create: `test/hub/claude/client_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub/claude/client_test.exs`:

```elixir
defmodule Hub.Claude.ClientTest do
  use ExUnit.Case

  alias Hub.Claude.Client

  describe "build_request/2" do
    test "builds correct request body for messages API" do
      body = Client.build_request("Extract signals from this transcript.", system: "You are an analyst.")

      assert body.model =~ "claude"
      assert length(body.messages) == 1
      assert hd(body.messages).role == "user"
      assert hd(body.messages).content == "Extract signals from this transcript."
      assert body.system == "You are an analyst."
    end

    test "includes max_tokens" do
      body = Client.build_request("Hello", max_tokens: 2048)
      assert body.max_tokens == 2048
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub/claude/client_test.exs
```

Expected: compilation error — `Hub.Claude.Client` not found.

- [ ] **Step 3: Implement the Claude client**

Create `lib/hub/claude/client.ex`:

```elixir
defmodule Hub.Claude.Client do
  @moduledoc """
  HTTP client for the Claude Messages API.
  """

  require Logger

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"
  @default_max_tokens 4096

  def chat(user_message, opts \\ []) do
    body = build_request(user_message, opts)

    case Req.post(@api_url,
      json: body,
      headers: [
        {"x-api-key", api_key()},
        {"anthropic-version", @api_version},
        {"content-type", "application/json"}
      ],
      receive_timeout: 120_000
    ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Claude API returned #{status}: #{inspect(body)}")
        {:error, "Claude API error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def build_request(user_message, opts \\ []) do
    %{
      model: opts[:model] || default_model(),
      max_tokens: opts[:max_tokens] || @default_max_tokens,
      messages: [%{role: "user", content: user_message}]
    }
    |> maybe_add_system(opts[:system])
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, system), do: Map.put(body, :system, system)

  defp api_key do
    Application.fetch_env!(:hub, :claude)[:api_key]
  end

  defp default_model do
    Application.fetch_env!(:hub, :claude)[:model] || "claude-sonnet-4-20250514"
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/hub/claude/client_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```
add claude API client
```

---

### Task 9: AI Processing Pipeline — Chunker + Extractor + Merger + Processor

**Files:**
- Create: `lib/hub/pipeline/chunker.ex`
- Create: `lib/hub/pipeline/extractor.ex`
- Create: `lib/hub/pipeline/merger.ex`
- Create: `lib/hub/pipeline/processor.ex`
- Create: `test/hub/pipeline/chunker_test.exs`
- Create: `test/hub/pipeline/extractor_test.exs`
- Create: `test/hub/pipeline/merger_test.exs`
- Create: `test/hub/pipeline/processor_test.exs`

- [ ] **Step 1: Write chunker test**

Create `test/hub/pipeline/chunker_test.exs`:

```elixir
defmodule Hub.Pipeline.ChunkerTest do
  use ExUnit.Case

  alias Hub.Pipeline.Chunker

  describe "chunk/2" do
    test "returns single chunk for short transcripts" do
      segments = for i <- 1..10 do
        %{"index" => i, "start_ms" => (i - 1) * 60_000, "end_ms" => i * 60_000,
          "speaker" => "Speaker A", "text" => "Segment #{i} content."}
      end

      chunks = Chunker.chunk(segments, max_duration_ms: 15 * 60_000)
      assert length(chunks) == 1
      assert length(hd(chunks)) == 10
    end

    test "splits long transcripts into chunks at speaker boundaries" do
      segments = for i <- 1..30 do
        speaker = if rem(i, 2) == 0, do: "Speaker A", else: "Speaker B"
        %{"index" => i, "start_ms" => (i - 1) * 120_000, "end_ms" => i * 120_000,
          "speaker" => speaker, "text" => "Segment #{i} content."}
      end

      # 30 segments * 2 min = 60 min, should split into ~4 chunks at 15 min each
      chunks = Chunker.chunk(segments, max_duration_ms: 15 * 60_000)
      assert length(chunks) >= 3
      assert length(chunks) <= 5

      # Every segment should appear in exactly one chunk
      all_indices = chunks |> List.flatten() |> Enum.map(& &1["index"]) |> Enum.sort()
      assert all_indices == Enum.to_list(1..30)
    end

    test "returns empty list for empty segments" do
      assert Chunker.chunk([], max_duration_ms: 15 * 60_000) == []
    end
  end
end
```

- [ ] **Step 2: Implement chunker**

Create `lib/hub/pipeline/chunker.ex`:

```elixir
defmodule Hub.Pipeline.Chunker do
  @moduledoc """
  Splits long transcript segments into time-bounded chunks,
  preferring to split at speaker change boundaries.
  """

  @default_max_duration_ms 15 * 60 * 1000

  def chunk([], _opts), do: []

  def chunk(segments, opts \\ []) do
    max_duration = opts[:max_duration_ms] || @default_max_duration_ms
    total_duration = total_duration_ms(segments)

    if total_duration <= max_duration do
      [segments]
    else
      do_chunk(segments, max_duration)
    end
  end

  defp do_chunk(segments, max_duration) do
    segments
    |> Enum.reduce({[], [], nil}, fn seg, {chunks, current_chunk, chunk_start} ->
      seg_start = seg["start_ms"]
      chunk_start = chunk_start || seg_start
      elapsed = seg_start - chunk_start

      if elapsed >= max_duration and current_chunk != [] do
        {[Enum.reverse(current_chunk) | chunks], [seg], seg_start}
      else
        {chunks, [seg | current_chunk], chunk_start}
      end
    end)
    |> then(fn {chunks, current_chunk, _} ->
      case current_chunk do
        [] -> Enum.reverse(chunks)
        _ -> Enum.reverse([Enum.reverse(current_chunk) | chunks])
      end
    end)
  end

  defp total_duration_ms([]), do: 0

  defp total_duration_ms(segments) do
    first = hd(segments)
    last = List.last(segments)
    (last["end_ms"] || 0) - (first["start_ms"] || 0)
  end
end
```

- [ ] **Step 3: Run chunker test**

```bash
mix test test/hub/pipeline/chunker_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 4: Write extractor test**

Create `test/hub/pipeline/extractor_test.exs`:

```elixir
defmodule Hub.Pipeline.ExtractorTest do
  use ExUnit.Case

  alias Hub.Pipeline.Extractor

  describe "build_prompt/2" do
    test "builds extraction prompt with metadata and transcript" do
      metadata = %{
        "topic" => "Client Check-in",
        "start_time" => "2026-03-30T14:00:00Z"
      }
      participants = ["Igor Kuznetsov", "Austin Smith"]
      transcript_text = "Igor Kuznetsov: Hello\nAustin Smith: Hi there"

      prompt = Extractor.build_prompt(transcript_text, participants: participants, metadata: metadata)

      assert prompt =~ "TenFore"
      assert prompt =~ "Client Check-in"
      assert prompt =~ "Igor Kuznetsov, Austin Smith"
      assert prompt =~ "Igor Kuznetsov: Hello"
      assert prompt =~ "feature_request"
    end
  end

  describe "parse_response/1" do
    test "parses valid JSON response" do
      json = ~s({"summary": "Test summary", "action_items": [], "signals": [], "client_names": ["Pine Valley"]})
      assert {:ok, parsed} = Extractor.parse_response(json)
      assert parsed["summary"] == "Test summary"
      assert parsed["client_names"] == ["Pine Valley"]
    end

    test "extracts JSON from markdown code blocks" do
      response = "Here is the extraction:\n```json\n{\"summary\": \"Test\", \"action_items\": [], \"signals\": [], \"client_names\": []}\n```"
      assert {:ok, parsed} = Extractor.parse_response(response)
      assert parsed["summary"] == "Test"
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Extractor.parse_response("not json at all")
    end
  end
end
```

- [ ] **Step 5: Implement extractor**

Create `lib/hub/pipeline/extractor.ex`:

```elixir
defmodule Hub.Pipeline.Extractor do
  @moduledoc """
  Builds extraction prompts and parses Claude API responses.
  """

  alias Hub.Claude

  @prompt_version "v1"

  @system_prompt """
  You are analyzing a transcript from a client conversation at TenFore, a golf course management software company. Extract structured data as JSON.
  """

  def extract(transcript_text, opts \\ []) do
    prompt = build_prompt(transcript_text, opts)

    case Claude.Client.chat(prompt, system: @system_prompt) do
      {:ok, response} -> parse_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  def prompt_version, do: @prompt_version

  def build_prompt(transcript_text, opts \\ []) do
    participants = opts[:participants] || []
    metadata = opts[:metadata] || %{}

    """
    Participants: #{Enum.join(participants, ", ")}
    Meeting topic: #{metadata["topic"] || "Unknown"}
    Date: #{metadata["start_time"] || "Unknown"}

    Extract the following as JSON (no markdown, just raw JSON):
    - summary: 2-3 sentence summary of this segment
    - action_items: [{text, assignee (if mentioned), due_date (if mentioned)}]
    - signals: [{type, content (exact quote or close paraphrase), speaker, confidence (0.0-1.0)}]
    - client_names: any golf course / client names mentioned

    Signal types:
    - feature_request: client asks for something that doesn't exist
    - bug_report: something isn't working as expected
    - competitor_mention: reference to competing products
    - churn_signal: dissatisfaction, evaluating alternatives
    - commitment: someone promises to do something by a date
    - positive_feedback: client expresses satisfaction

    Transcript:
    #{transcript_text}
    """
  end

  def parse_response(response) do
    # Try direct JSON parse first, then extract from markdown code blocks
    case Jason.decode(response) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
        case Regex.run(~r/```(?:json)?\s*\n?(.*?)\n?```/s, response) do
          [_, json_str] -> Jason.decode(json_str)
          nil -> {:error, "Could not parse Claude response as JSON: #{String.slice(response, 0, 200)}"}
        end
    end
  end
end
```

- [ ] **Step 6: Run extractor test**

```bash
mix test test/hub/pipeline/extractor_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 7: Write merger test**

Create `test/hub/pipeline/merger_test.exs`:

```elixir
defmodule Hub.Pipeline.MergerTest do
  use ExUnit.Case

  alias Hub.Pipeline.Merger

  describe "merge/1" do
    test "merges multiple chunk results" do
      results = [
        %{
          "summary" => "Discussed kiosk issues.",
          "action_items" => [%{"text" => "Fix Apple Pay", "assignee" => "Igor"}],
          "signals" => [%{"type" => "feature_request", "content" => "Apple Pay on kiosks", "speaker" => "Austin", "confidence" => 0.9}],
          "client_names" => ["Sawyer Creek"]
        },
        %{
          "summary" => "Reviewed subcourse switcher feedback.",
          "action_items" => [%{"text" => "Simplify switcher", "assignee" => "Igor"}],
          "signals" => [%{"type" => "bug_report", "content" => "Subcourse switcher is confusing", "speaker" => "Austin", "confidence" => 0.8}],
          "client_names" => ["Pine Valley", "Sawyer Creek"]
        }
      ]

      merged = Merger.merge(results)

      assert merged.summary =~ "kiosk"
      assert merged.summary =~ "subcourse"
      assert length(merged.action_items) == 2
      assert length(merged.signals) == 2
      assert "Sawyer Creek" in merged.client_names
      assert "Pine Valley" in merged.client_names
    end

    test "returns single result unwrapped" do
      result = %{
        "summary" => "Short meeting.",
        "action_items" => [],
        "signals" => [],
        "client_names" => []
      }

      merged = Merger.merge([result])
      assert merged.summary == "Short meeting."
    end
  end
end
```

- [ ] **Step 8: Implement merger**

Create `lib/hub/pipeline/merger.ex`:

```elixir
defmodule Hub.Pipeline.Merger do
  @moduledoc """
  Merges extraction results from multiple transcript chunks into a single result.
  """

  def merge([single]) do
    %{
      summary: single["summary"],
      action_items: single["action_items"] || [],
      signals: single["signals"] || [],
      client_names: single["client_names"] || []
    }
  end

  def merge(results) do
    %{
      summary: results |> Enum.map(& &1["summary"]) |> Enum.join(" "),
      action_items: results |> Enum.flat_map(& (&1["action_items"] || [])),
      signals: results |> Enum.flat_map(& (&1["signals"] || [])),
      client_names: results |> Enum.flat_map(& (&1["client_names"] || [])) |> Enum.uniq()
    }
  end
end
```

- [ ] **Step 9: Run merger test**

```bash
mix test test/hub/pipeline/merger_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 10: Write processor test**

Create `test/hub/pipeline/processor_test.exs`:

```elixir
defmodule Hub.Pipeline.ProcessorTest do
  use Hub.DataCase
  use Oban.Testing, repo: Hub.Repo

  alias Hub.Pipeline.Processor
  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "perform/1 with mocked extractor" do
    test "processes raw document and stores results" do
      # Insert a raw document
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{
          source: "zoom",
          source_id: "test-proc-123",
          content: "Igor: Hello\nAustin: Hi",
          segments: [
            %{"index" => 1, "start_ms" => 0, "end_ms" => 5000, "speaker" => "Igor", "text" => "Hello"},
            %{"index" => 2, "start_ms" => 5000, "end_ms" => 10000, "speaker" => "Austin", "text" => "Hi"}
          ],
          participants: ["Igor", "Austin"],
          metadata: %{"topic" => "Test Meeting", "start_time" => "2026-03-30T14:00:00Z"}
        })
        |> Hub.Repo.insert()

      # Use test extraction (bypasses Claude API)
      args = %{"raw_document_id" => raw_doc.id, "test_extraction" => %{
        "summary" => "Quick greeting.",
        "action_items" => [],
        "signals" => [%{"type" => "positive_feedback", "content" => "Friendly greeting", "speaker" => "Austin", "confidence" => 0.5}],
        "client_names" => []
      }}

      assert :ok = perform_job(Processor, args)

      processed = Hub.Repo.get_by!(ProcessedDocument, raw_document_id: raw_doc.id)
      assert processed.summary == "Quick greeting."

      signals = Hub.Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).type == "positive_feedback"
    end
  end
end
```

- [ ] **Step 11: Implement processor**

Create `lib/hub/pipeline/processor.ex`:

```elixir
defmodule Hub.Pipeline.Processor do
  @moduledoc """
  Oban worker that orchestrates AI extraction on a RawDocument.
  Chunks the transcript, sends each chunk to Claude, merges results,
  resolves clients, and stores ProcessedDocument + Signals.
  """

  use Oban.Worker, queue: :pipeline, max_attempts: 3

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}
  alias Hub.Clients.Resolver
  alias Hub.Pipeline.{Chunker, Extractor, Merger}
  alias Hub.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"raw_document_id" => raw_doc_id} = args}) do
    raw_doc = Repo.get!(RawDocument, raw_doc_id)

    with {:ok, extraction} <- extract(raw_doc, args),
         {:ok, processed_doc} <- store_processed(raw_doc, extraction),
         :ok <- store_signals(processed_doc, extraction.signals),
         :ok <- Resolver.resolve_and_link(raw_doc, extraction.client_names) do
      Phoenix.PubSub.broadcast(Hub.PubSub, "documents", {:document_processed, processed_doc.id})
      Logger.info("Processed document #{raw_doc_id} — #{length(extraction.signals)} signals extracted")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process document #{raw_doc_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract(raw_doc, %{"test_extraction" => test_data}) do
    {:ok, Merger.merge([test_data])}
  end

  defp extract(raw_doc, _args) do
    chunks = Chunker.chunk(raw_doc.segments)

    results =
      Enum.map(chunks, fn chunk_segments ->
        text = chunk_segments |> Enum.map(fn s -> "#{s["speaker"]}: #{s["text"]}" end) |> Enum.join("\n")
        case Extractor.extract(text, participants: raw_doc.participants, metadata: raw_doc.metadata) do
          {:ok, result} -> result
          {:error, reason} -> raise "Extraction failed: #{inspect(reason)}"
        end
      end)

    {:ok, Merger.merge(results)}
  end

  defp store_processed(raw_doc, extraction) do
    %ProcessedDocument{}
    |> ProcessedDocument.changeset(%{
      raw_document_id: raw_doc.id,
      summary: extraction.summary,
      action_items: extraction.action_items,
      model: Application.get_env(:hub, :claude)[:model] || "claude-sonnet-4-20250514",
      prompt_version: Extractor.prompt_version(),
      processed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp store_signals(processed_doc, signals) do
    Enum.each(signals, fn signal_data ->
      %Signal{}
      |> Signal.changeset(%{
        processed_document_id: processed_doc.id,
        type: signal_data["type"],
        content: signal_data["content"],
        speaker: signal_data["speaker"],
        confidence: signal_data["confidence"],
        metadata: Map.drop(signal_data, ["type", "content", "speaker", "confidence"])
      })
      |> Repo.insert!()
    end)

    :ok
  end
end
```

- [ ] **Step 12: Run processor test**

```bash
mix test test/hub/pipeline/processor_test.exs
```

Expected: 1 test, 0 failures.

- [ ] **Step 13: Commit**

```
add AI processing pipeline: chunker, extractor, merger, processor
```

---

### Task 10: Client Resolver

**Files:**
- Create: `lib/hub/clients/resolver.ex`
- Create: `test/hub/clients/resolver_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub/clients/resolver_test.exs`:

```elixir
defmodule Hub.Clients.ResolverTest do
  use Hub.DataCase

  alias Hub.Clients.{Client, Resolver}
  alias Hub.Documents.RawDocument

  describe "resolve_and_link/2" do
    test "creates new client and links to document" do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-1", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Sawyer Creek"])

      client = Repo.get_by!(Client, name: "Sawyer Creek")
      assert client

      linked = raw_doc |> Repo.preload(:clients) |> Map.get(:clients)
      assert length(linked) == 1
      assert hd(linked).id == client.id
    end

    test "matches existing client by name" do
      {:ok, existing} = %Client{} |> Client.changeset(%{name: "Pine Valley"}) |> Repo.insert()

      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-2", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Pine Valley"])
      assert Repo.aggregate(Client, :count) == 1

      linked = raw_doc |> Repo.preload(:clients) |> Map.get(:clients)
      assert hd(linked).id == existing.id
    end

    test "matches by alias" do
      {:ok, _} = %Client{} |> Client.changeset(%{name: "Sawyer Creek Golf Club", aliases: ["Sawyer Creek"]}) |> Repo.insert()

      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-3", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Sawyer Creek"])
      assert Repo.aggregate(Client, :count) == 1
    end

    test "does nothing for empty client names" do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-4", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, [])
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub/clients/resolver_test.exs
```

Expected: compilation error — `Hub.Clients.Resolver` not found.

- [ ] **Step 3: Add clients association to RawDocument**

In `lib/hub/documents/raw_document.ex`, add inside the schema block:

```elixir
many_to_many :clients, Hub.Clients.Client, join_through: "document_clients"
```

- [ ] **Step 4: Implement the resolver**

Create `lib/hub/clients/resolver.ex`:

```elixir
defmodule Hub.Clients.Resolver do
  @moduledoc """
  Resolves client names extracted from transcripts against existing client records.
  Creates new clients for unrecognized names. Links clients to raw documents.
  """

  alias Hub.Clients.Client
  alias Hub.Repo

  import Ecto.Query

  def resolve_and_link(_raw_doc, []), do: :ok

  def resolve_and_link(raw_doc, client_names) do
    Enum.each(client_names, fn name ->
      client = find_or_create(name)
      link_document(raw_doc, client)
    end)

    :ok
  end

  defp find_or_create(name) do
    case find_by_name_or_alias(name) do
      nil ->
        {:ok, client} =
          %Client{}
          |> Client.changeset(%{name: name})
          |> Repo.insert(on_conflict: :nothing, conflict_target: :name, returning: true)

        # on_conflict: :nothing may not return the record; re-fetch if needed
        client || Repo.get_by!(Client, name: name)

      client ->
        client
    end
  end

  defp find_by_name_or_alias(name) do
    downcased = String.downcase(name)

    # Exact name match first
    query = from c in Client, where: fragment("lower(?)", c.name) == ^downcased

    case Repo.one(query) do
      nil ->
        # Check aliases (jsonb array contains, case-insensitive)
        alias_query =
          from c in Client,
            where: fragment("EXISTS (SELECT 1 FROM jsonb_array_elements_text(?) AS alias WHERE lower(alias) = ?)", c.aliases, ^downcased)

        Repo.one(alias_query)

      client ->
        client
    end
  end

  defp link_document(raw_doc, client) do
    Repo.insert_all(
      "document_clients",
      [%{raw_document_id: raw_doc.id, client_id: client.id}],
      on_conflict: :nothing
    )
  end
end
```

- [ ] **Step 5: Run tests**

```bash
mix test test/hub/clients/resolver_test.exs
```

Expected: 4 tests, 0 failures.

- [ ] **Step 6: Commit**

```
add client resolver with fuzzy alias matching
```

---

### Task 11: LiveView — Feed Page

**Files:**
- Create: `lib/hub_web/live/feed_live.ex`
- Create: `lib/hub_web/components/document_card.ex`
- Create: `lib/hub_web/components/signal_badge.ex`
- Modify: `lib/hub_web/router.ex`
- Create: `test/hub_web/live/feed_live_test.exs`

- [ ] **Step 1: Write the test**

Create `test/hub_web/live/feed_live_test.exs`:

```elixir
defmodule HubWeb.FeedLiveTest do
  use HubWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "Feed page" do
    test "renders empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")
      assert html =~ "No transcripts yet"
    end

    test "renders processed documents", %{conn: conn} do
      {:ok, raw_doc} = insert_raw_document()
      {:ok, proc_doc} = insert_processed_document(raw_doc)
      insert_signal(proc_doc, "feature_request", "Apple Pay on kiosks")

      {:ok, view, html} = live(conn, "/")
      assert html =~ "Client Check-in"
      assert html =~ "Apple Pay on kiosks"
      assert html =~ "feature_request"
    end

    test "receives real-time updates via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      {:ok, raw_doc} = insert_raw_document(source_id: "realtime-1")
      {:ok, proc_doc} = insert_processed_document(raw_doc, summary: "Real-time test summary")

      Phoenix.PubSub.broadcast(Hub.PubSub, "documents", {:document_processed, proc_doc.id})

      assert render(view) =~ "Real-time test summary"
    end
  end

  defp insert_raw_document(overrides \\ []) do
    %RawDocument{}
    |> RawDocument.changeset(%{
      source: "zoom",
      source_id: overrides[:source_id] || "feed-test-1",
      content: "Igor: Hello",
      segments: [],
      participants: ["Igor Kuznetsov", "Austin Smith"],
      metadata: %{"topic" => "Client Check-in", "start_time" => "2026-03-30T14:00:00Z"}
    })
    |> Hub.Repo.insert()
  end

  defp insert_processed_document(raw_doc, overrides \\ []) do
    %ProcessedDocument{}
    |> ProcessedDocument.changeset(%{
      raw_document_id: raw_doc.id,
      summary: overrides[:summary] || "Discussed client issues.",
      action_items: [],
      model: "claude-sonnet-4-20250514",
      prompt_version: "v1",
      processed_at: DateTime.utc_now()
    })
    |> Hub.Repo.insert()
  end

  defp insert_signal(processed_doc, type, content) do
    %Signal{}
    |> Signal.changeset(%{
      processed_document_id: processed_doc.id,
      type: type,
      content: content,
      speaker: "Austin Smith",
      confidence: 0.9
    })
    |> Hub.Repo.insert()
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/hub_web/live/feed_live_test.exs
```

Expected: route/module not found errors.

- [ ] **Step 3: Create signal badge component**

Create `lib/hub_web/components/signal_badge.ex`:

```elixir
defmodule HubWeb.Components.SignalBadge do
  use Phoenix.Component

  @colors %{
    "feature_request" => "bg-blue-100 text-blue-800",
    "bug_report" => "bg-red-100 text-red-800",
    "competitor_mention" => "bg-purple-100 text-purple-800",
    "churn_signal" => "bg-orange-100 text-orange-800",
    "commitment" => "bg-yellow-100 text-yellow-800",
    "positive_feedback" => "bg-green-100 text-green-800"
  }

  @labels %{
    "feature_request" => "Feature Request",
    "bug_report" => "Bug Report",
    "competitor_mention" => "Competitor",
    "churn_signal" => "Churn Risk",
    "commitment" => "Commitment",
    "positive_feedback" => "Positive"
  }

  attr :type, :string, required: true
  attr :class, :string, default: ""

  def signal_badge(assigns) do
    assigns =
      assigns
      |> assign(:color, Map.get(@colors, assigns.type, "bg-gray-100 text-gray-800"))
      |> assign(:label, Map.get(@labels, assigns.type, assigns.type))

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{@color} #{@class}"}>
      <%= @label %>
    </span>
    """
  end
end
```

- [ ] **Step 4: Create document card component**

Create `lib/hub_web/components/document_card.ex`:

```elixir
defmodule HubWeb.Components.DocumentCard do
  use Phoenix.Component

  import HubWeb.Components.SignalBadge

  attr :document, :map, required: true

  def document_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6 mb-4 border border-gray-200">
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-lg font-semibold text-gray-900">
          <%= @document.raw_document.metadata["topic"] || "Untitled Meeting" %>
        </h3>
        <time class="text-sm text-gray-500">
          <%= format_date(@document.processed_at) %>
        </time>
      </div>

      <div class="text-sm text-gray-600 mb-3">
        <%= Enum.join(@document.raw_document.participants, ", ") %>
      </div>

      <p class="text-gray-700 mb-4"><%= @document.summary %></p>

      <div class="flex flex-wrap gap-2">
        <.signal_badge :for={signal <- @document.signals} type={signal.type} />
      </div>
    </div>
    """
  end

  defp format_date(nil), do: ""

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
```

- [ ] **Step 5: Create the Feed LiveView**

Create `lib/hub_web/live/feed_live.ex`:

```elixir
defmodule HubWeb.FeedLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard

  alias Hub.Documents.{ProcessedDocument, RawDocument, Signal}
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hub.PubSub, "documents")
    end

    documents = load_documents()

    {:ok, assign(socket, documents: documents, page_title: "Feed")}
  end

  @impl true
  def handle_info({:document_processed, _doc_id}, socket) do
    documents = load_documents()
    {:noreply, assign(socket, documents: documents)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold text-gray-900 mb-8">Client Intelligence Feed</h1>

      <%= if @documents == [] do %>
        <div class="text-center py-12 text-gray-500">
          <p class="text-lg">No transcripts yet</p>
          <p class="text-sm mt-2">Transcripts will appear here once Zoom recordings are processed.</p>
        </div>
      <% else %>
        <div>
          <.document_card :for={doc <- @documents} document={doc} />
        </div>
      <% end %>
    </div>
    """
  end

  defp load_documents do
    from(pd in ProcessedDocument,
      join: rd in assoc(pd, :raw_document),
      preload: [:signals, raw_document: rd],
      order_by: [desc: pd.processed_at],
      limit: 50
    )
    |> Repo.all()
  end
end
```

- [ ] **Step 6: Add route**

In `lib/hub_web/router.ex`, replace the default `"/"` route in the browser scope:

```elixir
scope "/", HubWeb do
  pipe_through :browser
  live "/", FeedLive
end
```

- [ ] **Step 7: Run tests**

```bash
mix test test/hub_web/live/feed_live_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 8: Commit**

```
add feed LiveView with document cards and signal badges
```

---

### Task 12: LiveView — Document Detail + Client View + Search

**Files:**
- Create: `lib/hub_web/live/document_live.ex`
- Create: `lib/hub_web/live/client_live.ex`
- Create: `lib/hub_web/live/search_live.ex`
- Modify: `lib/hub_web/router.ex`
- Create: `test/hub_web/live/search_live_test.exs`

- [ ] **Step 1: Write search test**

Create `test/hub_web/live/search_live_test.exs`:

```elixir
defmodule HubWeb.SearchLiveTest do
  use HubWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "Search page" do
    test "renders search form", %{conn: conn} do
      {:ok, view, html} = live(conn, "/search")
      assert html =~ "Search"
      assert has_element?(view, "input[name=\"q\"]")
    end

    test "returns matching results", %{conn: conn} do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{
          source: "zoom", source_id: "search-1", content: "Discussion about Apple Pay integration",
          segments: [], participants: ["Igor"], metadata: %{"topic" => "Kiosk Review"}
        })
        |> Hub.Repo.insert()

      {:ok, proc_doc} =
        %ProcessedDocument{}
        |> ProcessedDocument.changeset(%{
          raw_document_id: raw_doc.id, summary: "Discussed Apple Pay for kiosks.",
          action_items: [], model: "claude-sonnet-4-20250514", prompt_version: "v1", processed_at: DateTime.utc_now()
        })
        |> Hub.Repo.insert()

      {:ok, view, _html} = live(conn, "/search")
      view |> form("form", %{q: "Apple Pay"}) |> render_submit()

      assert render(view) =~ "Apple Pay"
      assert render(view) =~ "Kiosk Review"
    end

    test "shows no results message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      view |> form("form", %{q: "nonexistent query xyz"}) |> render_submit()

      assert render(view) =~ "No results"
    end
  end
end
```

- [ ] **Step 2: Create Document Detail LiveView**

Create `lib/hub_web/live/document_live.ex`:

```elixir
defmodule HubWeb.DocumentLive do
  use HubWeb, :live_view

  import HubWeb.Components.SignalBadge

  alias Hub.Documents.{ProcessedDocument, RawDocument}
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    processed_doc =
      from(pd in ProcessedDocument,
        where: pd.id == ^id,
        preload: [:signals, raw_document: ^from(rd in RawDocument, preload: :clients)]
      )
      |> Repo.one!()

    {:ok, assign(socket, document: processed_doc, page_title: processed_doc.raw_document.metadata["topic"] || "Document")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <.link navigate="/" class="text-blue-600 hover:underline mb-4 inline-block">&larr; Back to Feed</.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-2">
        <%= @document.raw_document.metadata["topic"] || "Untitled Meeting" %>
      </h1>

      <div class="text-sm text-gray-600 mb-6">
        <%= Enum.join(@document.raw_document.participants, ", ") %>
        &middot;
        <%= Calendar.strftime(@document.processed_at, "%b %d, %Y %H:%M") %>
      </div>

      <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
        <h2 class="text-lg font-semibold mb-2">Summary</h2>
        <p class="text-gray-700"><%= @document.summary %></p>
      </div>

      <%= if @document.signals != [] do %>
        <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
          <h2 class="text-lg font-semibold mb-4">Signals</h2>
          <div class="space-y-3">
            <div :for={signal <- @document.signals} class="flex items-start gap-3">
              <.signal_badge type={signal.type} />
              <div>
                <p class="text-gray-700">"<%= signal.content %>"</p>
                <p class="text-sm text-gray-500">— <%= signal.speaker %></p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @document.action_items != [] do %>
        <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
          <h2 class="text-lg font-semibold mb-4">Action Items</h2>
          <ul class="list-disc list-inside space-y-1 text-gray-700">
            <li :for={item <- @document.action_items}>
              <%= item["text"] %>
              <%= if item["assignee"] do %><span class="text-gray-500"> — <%= item["assignee"] %></span><% end %>
            </li>
          </ul>
        </div>
      <% end %>

      <div class="bg-white rounded-lg shadow p-6 border border-gray-200">
        <h2 class="text-lg font-semibold mb-4">Full Transcript</h2>
        <div class="text-sm text-gray-700 whitespace-pre-wrap font-mono"><%= @document.raw_document.content %></div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 3: Create Client LiveView**

Create `lib/hub_web/live/client_live.ex`:

```elixir
defmodule HubWeb.ClientLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard

  alias Hub.Clients.Client
  alias Hub.Documents.{ProcessedDocument, RawDocument}
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    client = Repo.get!(Client, id)

    documents =
      from(pd in ProcessedDocument,
        join: rd in assoc(pd, :raw_document),
        join: dc in "document_clients", on: dc.raw_document_id == rd.id,
        where: dc.client_id == ^id,
        preload: [:signals, raw_document: rd],
        order_by: [desc: pd.processed_at]
      )
      |> Repo.all()

    signal_counts =
      documents
      |> Enum.flat_map(& &1.signals)
      |> Enum.frequencies_by(& &1.type)

    {:ok, assign(socket, client: client, documents: documents, signal_counts: signal_counts, page_title: client.name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <.link navigate="/" class="text-blue-600 hover:underline mb-4 inline-block">&larr; Back to Feed</.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-2"><%= @client.name %></h1>

      <div class="flex gap-4 mb-8 text-sm text-gray-600">
        <span><%= length(@documents) %> conversations</span>
        <span :for={{type, count} <- @signal_counts}>
          <%= type %>: <%= count %>
        </span>
      </div>

      <%= if @documents == [] do %>
        <p class="text-gray-500">No conversations with this client yet.</p>
      <% else %>
        <.document_card :for={doc <- @documents} document={doc} />
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 4: Create Search LiveView**

Create `lib/hub_web/live/search_live.ex`:

```elixir
defmodule HubWeb.SearchLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard

  alias Hub.Documents.{ProcessedDocument, RawDocument, Signal}
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: nil, page_title: "Search")}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    results = if String.trim(query) == "", do: nil, else: search(query)
    {:noreply, assign(socket, query: query, results: results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">Search Transcripts</h1>

      <form phx-submit="search" class="mb-8">
        <div class="flex gap-2">
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="Search transcripts, signals, action items..."
            class="flex-1 rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button type="submit" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700">
            Search
          </button>
        </div>
      </form>

      <%= cond do %>
        <% is_nil(@results) -> %>
          <p class="text-gray-500 text-center">Enter a search query to find transcripts.</p>
        <% @results == [] -> %>
          <p class="text-gray-500 text-center">No results found for "<%= @query %>"</p>
        <% true -> %>
          <p class="text-sm text-gray-600 mb-4"><%= length(@results) %> result(s)</p>
          <.document_card :for={doc <- @results} document={doc} />
      <% end %>
    </div>
    """
  end

  defp search(query) do
    pattern = "%#{query}%"

    from(pd in ProcessedDocument,
      join: rd in assoc(pd, :raw_document),
      where: ilike(rd.content, ^pattern) or ilike(pd.summary, ^pattern),
      preload: [:signals, raw_document: rd],
      order_by: [desc: pd.processed_at],
      limit: 50
    )
    |> Repo.all()
  end
end
```

- [ ] **Step 5: Add routes**

In `lib/hub_web/router.ex`, add to the browser scope:

```elixir
live "/documents/:id", DocumentLive
live "/clients/:id", ClientLive
live "/search", SearchLive
```

- [ ] **Step 6: Update document card to link to detail view**

In `lib/hub_web/components/document_card.ex`, wrap the title in a link:

```elixir
<.link navigate={"/documents/#{@document.id}"} class="text-lg font-semibold text-gray-900 hover:text-blue-600">
  <%= @document.raw_document.metadata["topic"] || "Untitled Meeting" %>
</.link>
```

- [ ] **Step 7: Run tests**

```bash
mix test test/hub_web/live/search_live_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 8: Run all tests**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```
add document detail, client timeline, and search LiveViews
```

---

### Task 13: Navigation Layout + Styling

**Files:**
- Modify: `lib/hub_web/components/layouts/app.html.heex`

- [ ] **Step 1: Update the app layout**

Replace the default Phoenix header in `lib/hub_web/components/layouts/app.html.heex` with a navigation bar:

```heex
<header class="bg-white border-b border-gray-200">
  <nav class="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between">
    <.link navigate="/" class="text-xl font-bold text-gray-900">TenFore Hub</.link>
    <div class="flex gap-6 text-sm">
      <.link navigate="/" class="text-gray-600 hover:text-gray-900">Feed</.link>
      <.link navigate="/search" class="text-gray-600 hover:text-gray-900">Search</.link>
    </div>
  </nav>
</header>
<main class="min-h-screen bg-gray-50">
  <.flash_group flash={@flash} />
  <%= @inner_content %>
</main>
```

- [ ] **Step 2: Verify visually**

```bash
mix phx.server
```

Open `http://localhost:4000` — verify the layout renders with nav bar and empty state.

- [ ] **Step 3: Run all tests**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```
add navigation layout and styling
```

---

### Task 14: Zoom Backfill Script

**Files:**
- Create: `lib/hub/plugins/zoom/backfill.ex`
- Create: `lib/mix/tasks/hub.zoom.backfill.ex`

- [ ] **Step 1: Create the backfill module**

Create `lib/hub/plugins/zoom/backfill.ex`:

```elixir
defmodule Hub.Plugins.Zoom.Backfill do
  @moduledoc """
  Pulls historical Zoom recording transcripts for all users on the account.
  """

  alias Hub.Plugins.Zoom.{Auth, Client}

  require Logger

  def run(days_back \\ 30) do
    to_date = Date.utc_today() |> Date.to_iso8601()
    from_date = Date.utc_today() |> Date.add(-days_back) |> Date.to_iso8601()

    Logger.info("Backfilling Zoom transcripts from #{from_date} to #{to_date}")

    with {:ok, users} <- list_users() do
      users
      |> Enum.each(fn user ->
        Logger.info("Fetching recordings for #{user["email"]}")
        backfill_user(user["id"], from_date, to_date)
      end)
    end
  end

  defp list_users do
    with {:ok, token} <- Auth.get_token() do
      case Req.get("https://api.zoom.us/v2/users",
        params: [status: "active", page_size: 300],
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: %{"users" => users}}} -> {:ok, users}
        {:ok, %{status: status, body: body}} -> {:error, "List users failed: #{status} #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp backfill_user(user_id, from_date, to_date) do
    case Client.list_user_recordings(user_id, from_date, to_date) do
      {:ok, %{"meetings" => meetings}} ->
        meetings
        |> Enum.each(fn meeting ->
          transcript_files =
            (meeting["recording_files"] || [])
            |> Enum.filter(fn f -> f["file_type"] == "TRANSCRIPT" end)

          Enum.each(transcript_files, fn file ->
            %{
              meeting_uuid: meeting["uuid"],
              topic: meeting["topic"],
              host_email: meeting["host_email"],
              start_time: meeting["start_time"],
              download_url: file["download_url"]
            }
            |> Hub.Plugins.Zoom.FetchWorker.new()
            |> Oban.insert!()
          end)
        end)

        Logger.info("Enqueued #{length(meetings)} meeting(s) for user #{user_id}")

      {:error, reason} ->
        Logger.error("Failed to list recordings for user #{user_id}: #{inspect(reason)}")
    end
  end
end
```

- [ ] **Step 2: Create the Mix task**

Create `lib/mix/tasks/hub.zoom.backfill.ex`:

```elixir
defmodule Mix.Tasks.Hub.Zoom.Backfill do
  @moduledoc "Backfill Zoom transcripts for the last N days (default: 30)"
  use Mix.Task

  @shortdoc "Backfill Zoom transcripts"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    days = case args do
      [days_str | _] -> String.to_integer(days_str)
      [] -> 30
    end

    Hub.Plugins.Zoom.Backfill.run(days)
  end
end
```

- [ ] **Step 3: Commit**

```
add zoom transcript backfill mix task
```

---

### Task 15: Wire Up Supervision Tree + Final Integration

**Files:**
- Modify: `lib/hub/application.ex`
- Modify: `config/config.exs`
- Modify: `config/test.exs`

- [ ] **Step 1: Update application.ex**

In `lib/hub/application.ex`, set up the full supervision tree:

```elixir
def start(_type, _args) do
  children = [
    Hub.Repo,
    {Oban, Application.fetch_env!(:hub, Oban)},
    HubWeb.Telemetry,
    {DNSCluster, query: Application.get_env(:hub, :dns_cluster_query) || :ignore},
    {Phoenix.PubSub, name: Hub.PubSub},
    HubWeb.Endpoint
  ] ++ zoom_children()

  opts = [strategy: :one_for_one, name: Hub.Supervisor]
  Supervisor.start_link(children, opts)
end

defp zoom_children do
  config = Application.get_env(:hub, :zoom)

  if config && config[:account_id] do
    [Hub.Plugins.Zoom.Auth]
  else
    []
  end
end
```

- [ ] **Step 2: Ensure test config disables Zoom auth**

In `config/test.exs`, make sure Zoom config doesn't have real credentials so the Auth GenServer doesn't start:

```elixir
config :hub, :zoom,
  account_id: nil,
  client_id: nil,
  client_secret: nil,
  webhook_secret: "test-secret"

config :hub, :claude,
  api_key: "test-key",
  model: "claude-sonnet-4-20250514"
```

- [ ] **Step 3: Run full test suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 4: Start the server and verify**

```bash
mix phx.server
```

Open `http://localhost:4000` — verify empty feed renders. Visit `/search` — verify search page renders.

- [ ] **Step 5: Commit**

```
wire up supervision tree and finalize integration
```

---

## Summary

| Task | What it builds | Depends on |
|------|---------------|------------|
| 1 | Phoenix scaffold + Postgres + Oban | — |
| 2 | raw_documents schema | 1 |
| 3 | processed_documents, signals, clients schemas | 2 |
| 4 | VTT parser | 1 |
| 5 | Zoom S2S OAuth auth GenServer | 1 |
| 6 | Zoom webhook controller + API client | 2, 5 |
| 7 | Zoom fetch worker (Oban job) | 4, 6 |
| 8 | Claude API client | 1 |
| 9 | AI processing pipeline (chunker, extractor, merger, processor) | 3, 8 |
| 10 | Client resolver | 3 |
| 11 | Feed LiveView | 3, 9 |
| 12 | Document detail, client, search LiveViews | 11 |
| 13 | Navigation layout | 12 |
| 14 | Zoom backfill | 5, 7 |
| 15 | Supervision tree + integration | all |
