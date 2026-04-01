defmodule HubWeb.FeedLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard

  alias Hub.Documents.ProcessedDocument
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
