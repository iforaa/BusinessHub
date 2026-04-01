defmodule HubWeb.DocumentLive do
  use HubWeb, :live_view

  import HubWeb.Components.SignalBadge

  alias Hub.Documents.{ProcessedDocument, RawDocument}
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    processed_doc =
      from(pd in ProcessedDocument,
        where: pd.id == ^id,
        preload: [:signals, raw_document: ^from(rd in RawDocument, preload: :clients)]
      )
      |> Repo.one!()

    {:ok, assign(socket, document: processed_doc, page_title: processed_doc.raw_document.metadata["topic"] || "Document")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <.link navigate="/" class="text-blue-600 hover:underline mb-4 inline-block">&larr; Back to Feed</.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-2">
        <%= @document.raw_document.metadata["topic"] || "Untitled Meeting" %>
      </h1>

      <div class="text-sm text-gray-600 mb-6">
        <%= Enum.join(@document.raw_document.participants, ", ") %>
        &middot;
        <%= Calendar.strftime(@document.processed_at, "%b %d, %Y %H:%M") %>
      </div>

      <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
        <h2 class="text-lg font-semibold mb-2">Summary</h2>
        <p class="text-gray-700"><%= @document.summary %></p>
      </div>

      <%= if @document.signals != [] do %>
        <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
          <h2 class="text-lg font-semibold mb-4">Signals</h2>
          <div class="space-y-3">
            <div :for={signal <- @document.signals} class="flex items-start gap-3">
              <.signal_badge type={signal.type} />
              <div>
                <p class="text-gray-700">"<%= signal.content %>"</p>
                <p class="text-sm text-gray-500">— <%= signal.speaker %></p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @document.action_items != [] do %>
        <div class="bg-white rounded-lg shadow p-6 mb-6 border border-gray-200">
          <h2 class="text-lg font-semibold mb-4">Action Items</h2>
          <ul class="list-disc list-inside space-y-1 text-gray-700">
            <li :for={item <- @document.action_items}>
              <%= item["text"] %>
              <%= if item["assignee"] do %><span class="text-gray-500"> — <%= item["assignee"] %></span><% end %>
            </li>
          </ul>
        </div>
      <% end %>

      <div class="bg-white rounded-lg shadow p-6 border border-gray-200">
        <h2 class="text-lg font-semibold mb-4">Full Transcript</h2>
        <div class="text-sm text-gray-700 whitespace-pre-wrap font-mono"><%= @document.raw_document.content %></div>
      </div>
    </div>
    """
  end
end
