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
