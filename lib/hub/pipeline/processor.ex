defmodule Hub.Pipeline.Processor do
  use Oban.Worker, queue: :pipeline, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    :ok
  end
end
