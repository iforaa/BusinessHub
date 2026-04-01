defmodule HubWeb.Components.DocumentCard do
  use Phoenix.Component

  import HubWeb.Components.SignalBadge

  attr :document, :map, required: true

  def document_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6 mb-4 border border-gray-200">
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-lg font-semibold text-gray-900">
          <%= @document.raw_document.metadata["topic"] || "Untitled Meeting" %>
        </h3>
        <time class="text-sm text-gray-500">
          <%= format_date(@document.processed_at) %>
        </time>
      </div>

      <div class="text-sm text-gray-600 mb-3">
        <%= Enum.join(@document.raw_document.participants, ", ") %>
      </div>

      <p class="text-gray-700 mb-4"><%= @document.summary %></p>

      <div class="space-y-2">
        <div :for={signal <- @document.signals} class="flex items-start gap-2">
          <.signal_badge type={signal.type} />
          <span class="text-sm text-gray-600"><%= signal.content %></span>
        </div>
      </div>
    </div>
    """
  end

  defp format_date(nil), do: ""

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
