# Live As-You-Type Search

## Goal

Replace the current submit-based `ilike` search with instant, as-you-type full-text search across all transcripts. Results show highlighted excerpts grouped by conversation, with the excerpt as the primary visual element.

## Backend

### PostgreSQL Full-Text Search

Add a `search_vector tsvector` column to `raw_documents` with a GIN index. This enables sub-50ms keyword search regardless of transcript length.

**Column & index:**
```sql
ALTER TABLE raw_documents ADD COLUMN search_vector tsvector;
CREATE INDEX raw_documents_search_idx ON raw_documents USING GIN (search_vector);
```

**DB trigger** to auto-populate on insert/update:
```sql
CREATE OR REPLACE FUNCTION raw_documents_search_trigger() RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER raw_documents_search_update
  BEFORE INSERT OR UPDATE OF content ON raw_documents
  FOR EACH ROW EXECUTE FUNCTION raw_documents_search_trigger();
```

Using a trigger (not Ecto callback) ensures the vector is populated regardless of ingestion path.

**Backfill existing rows:**
```sql
UPDATE raw_documents SET search_vector = to_tsvector('english', coalesce(content, ''));
```

### Search Query

```elixir
def search(query) do
  tsquery = sanitize_query(query)

  from(rd in RawDocument,
    where: fragment("? @@ to_tsquery('english', ?)", rd.search_vector, ^tsquery),
    select: %{
      id: rd.id,
      metadata: rd.metadata,
      participants: rd.participants,
      ingested_at: rd.ingested_at,
      rank: fragment("ts_rank(?, to_tsquery('english', ?))", rd.search_vector, ^tsquery),
      excerpts: fragment(
        "ts_headline('english', ?, to_tsquery('english', ?), 'MaxFragments=3,MaxWords=30,MinWords=15,StartSel=<mark>,StopSel=</mark>')",
        rd.content, ^tsquery
      )
    },
    order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", rd.search_vector, ^tsquery)],
    limit: 30
  )
  |> Repo.all()
end
```

**Query sanitization:** Convert user input to a tsquery-safe string. Use `websearch_to_tsquery` for multi-word queries and append `:*` to the last word for prefix matching (as-you-type feel). Strip special characters that would break tsquery syntax.

**Excerpts:** `ts_headline` returns up to 3 fragments per document with `<mark>` tags around matches. These render directly in the template using Phoenix's `raw/1` helper.

## Frontend

### LiveView Input

Replace the current `phx-submit="search"` form with `phx-change` on the input:

```heex
<input
  type="text"
  name="q"
  value={@query}
  phx-change="search"
  phx-debounce="200"
  placeholder="Search transcripts..."
/>
```

- 200ms debounce prevents firing on every keystroke
- Empty input clears search and shows the normal feed
- Any text replaces the feed area with search results

### Result Layout

Each result is a conversation card. Title, participants, and date form a single subtle header line. Excerpts are the main content, slightly larger text, with highlighted terms in yellow.

```
┌──────────────────────────────────────────────────────────┐
│ Standup: Web/Backend · Apr 1, 2026 · jarrette, chris    │  small, gray, muted
│──────────────────────────────────────────────────────────│
│  ...the way that Order Post works, which is the          │
│  [trade time] discount wasn't applied correctly...       │  larger text, []=highlight
│                                                          │
│  ...Fox failed to [discount] the [trade] times           │  second match
│  for some reason...                                      │
└──────────────────────────────────────────────────────────┘
```

- **Header:** topic + date + participants, one line, `text-xs text-gray-400`
- **Excerpts:** `text-sm text-gray-700`, with `<mark>` styled as `bg-yellow-100 text-yellow-900 rounded px-0.5`
- Multiple excerpts separated by `my-2` spacing, no repeated headers
- Clicking the card navigates to the full transcript (`/documents/raw/:id`)
- Result count shown above results: "12 results for 'trade time'"

### State Management

Two modes for the feed area, driven by `@query`:
- `@query == ""` → show normal document feed (existing behavior)
- `@query != ""` → show search results

The people sidebar remains visible and functional during search. Clearing the search input returns to the feed (or the active person filter).

## Migration

Single migration that:
1. Adds `search_vector tsvector` column (nullable, no default)
2. Creates the GIN index
3. Creates the trigger function and trigger
4. Backfills existing rows

## Out of Scope

- Fuzzy/typo-tolerant matching (would need pg_trgm extension)
- Searching processed summaries or signals (raw transcript only)
- Pagination beyond 30 results
- Search result persistence or history
