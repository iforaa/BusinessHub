# People Index + Granola Ingest — Design Spec

**Date:** 2026-04-01

## People Table

New `people` table:

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| name | string | unique, not null |
| email | string | nullable |
| aliases | jsonb | default [] |
| metadata | jsonb | default {} |

Join table `document_people` (raw_document_id, person_id) with unique index.

## Auto-creation (People Resolver)

Same pattern as `Hub.Clients.Resolver`:
- On document ingestion, each participant name is matched against `people` (case-insensitive name or alias)
- Unrecognized names create new `Person` records
- Called from the processing pipeline alongside client resolution

## People LiveViews

- `/people` — alphabetical list of all people with conversation count
- `/people/:id` — all conversations that person participated in (reuses document card component)
- "People" link added to nav bar

## Granola Transcript Ingest

Seed all 14 Granola meetings as raw_documents (source: "granola"). For meetings with transcripts, store full text and hand-written AI extraction. For meetings returning null transcripts, skip them.

Run people resolver on seeded data to auto-populate the people table.

## Explicitly Not In Scope

- Duplicate merging UI
- Editing people records
- Auto-linking people to clients
