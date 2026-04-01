# TenFore Hub

Corporate knowledge platform that ingests client conversations from Zoom (and later Slack, email, GitHub, Figma), processes them with AI, and surfaces actionable signals through a real-time dashboard.

## Tech Stack

- **Elixir / Phoenix** with LiveView
- **PostgreSQL** via Ecto
- **Oban** for job processing (Postgres-backed)
- **Claude API** for transcript extraction

## Architecture

Plugin-based ingestion → AI processing pipeline → LiveView dashboard. Each plugin is a GenServer under supervision + Oban workers for async jobs. Starting with Zoom transcript plugin.

## Commits

- Always use `/my-commit` for committing
- Always run `/simplify` before committing
- Do NOT add `Co-Authored-By` lines to commits
