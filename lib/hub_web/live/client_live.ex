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
