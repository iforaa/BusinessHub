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
