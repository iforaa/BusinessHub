defmodule Hub.Plugins.Zoom.PollWorker do
  use Oban.Worker, queue: :zoom, max_attempts: 3

  alias Hub.Plugins.Zoom.Backfill

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Polling Zoom for new recordings...")
    Backfill.run(1)
    :ok
  end
end
