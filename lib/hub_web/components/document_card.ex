defmodule HubWeb.Components.DocumentCard do
  use Phoenix.Component

  import HubWeb.Helpers, only: [format_date: 1]

  attr :document, :map, required: true
  attr :people_map, :map, default: %{}

  def document_card(assigns) do
    processed = assigns.document.processed_document

    assigns =
      assigns
      |> assign(:processed, processed)
      |> assign(:doc_link, if(processed,
        do: "/documents/#{processed.id}",
        else: "/documents/raw/#{assigns.document.id}"
      ))
      |> assign(:last_participant_idx, length(assigns.document.participants) - 1)

    ~H"""
    <.link navigate={@doc_link} class="block">
      <div class="rounded-xl mb-3 transition-all" style="background: #fff; border: 1px solid #e8e5df; padding: 14px 18px;" onmouseover="this.style.borderColor='#d4cdc0'; this.style.boxShadow='0 2px 8px rgba(0,0,0,0.04)'" onmouseout="this.style.borderColor='#e8e5df'; this.style.boxShadow='none'">
        <div class="flex items-baseline justify-between mb-1">
          <h3 class="text-[15px] font-semibold" style="color: #2d2a26;">
            <%= @document.metadata["topic"] || "Untitled Meeting" %>
            <%= unless @processed do %>
              <span class="text-[11px] font-medium ml-2 px-2 py-0.5 rounded" style="background: #f0ece4; color: #a09888;">Unprocessed</span>
            <% end %>
          </h3>
          <span class="text-xs flex-shrink-0 ml-3" style="color: #a09888;">
            <%= format_date(@document.metadata["start_time"] || @document.ingested_at) %>
          </span>
        </div>

        <div class="text-xs mb-2" style="color: #a09888;">
          <%= for {name, idx} <- Enum.with_index(@document.participants) do %>
            <%= name %><%= if idx < @last_participant_idx, do: ", " %>
          <% end %>
        </div>

        <%= if @processed do %>
          <p class="text-sm leading-relaxed" style="color: #5c5549;"><%= @processed.summary %></p>

          <%= if @processed.signals != [] do %>
            <div class="flex gap-1.5 flex-wrap mt-2.5">
              <span :for={signal <- @processed.signals} class={"text-[11px] px-2 py-0.5 rounded font-medium " <> Hub.Signals.style(signal.type)} >
                <%= Hub.Signals.label(signal.type) %>
              </span>
            </div>
          <% end %>
        <% else %>
          <p class="text-sm italic" style="color: #a09888;"><%= transcript_preview(@document.content) %></p>
        <% end %>
      </div>
    </.link>
    """
  end

  defp transcript_preview(nil), do: "No content"
  defp transcript_preview(content) when byte_size(content) <= 200, do: content
  defp transcript_preview(content), do: String.slice(content, 0, 200) <> "..."

end
