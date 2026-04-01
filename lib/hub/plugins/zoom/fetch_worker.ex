defmodule Hub.Plugins.Zoom.FetchWorker do
  use Oban.Worker, queue: :zoom, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    :ok
  end
end
