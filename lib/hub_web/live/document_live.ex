defmodule HubWeb.DocumentLive do
  use HubWeb, :live_view

  import HubWeb.Helpers, only: [format_date: 1]

  alias Hub.Documents.RawDocument
  alias Hub.People.Person
  alias Hub.Repo

  import Ecto.Query

  @fallback_colors {
    {"bg-[#f5f8f2] border-[#dfe8d8]", "color: #7a8b6e"},
    {"bg-[#f8f5f0] border-[#e8dfd4]", "color: #8b7a5e"},
    {"bg-[#f0f5f8] border-[#d4dfe8]", "color: #5e7a8b"},
    {"bg-[#f8f0f5] border-[#e8d4df]", "color: #8b5e7a"},
    {"bg-[#f5f5f0] border-[#e0e0d8]", "color: #7a7a6e"}
  }

  @speaker_line ~r/^([^:]+):\s+(.+)$/

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    {raw_doc, processed_doc} = load_raw_document(id)

    messages = parse_transcript(raw_doc.content)
    {color_map, avatar_map} = build_speaker_maps(messages)

    {:noreply, assign(socket,
      raw_document: raw_doc,
      processed: processed_doc,
      messages: messages,
      color_map: color_map,
      avatar_map: avatar_map,
      page_title: (processed_doc && processed_doc.ai_title) || raw_doc.metadata["topic"] || "Document"
    )}
  end

  defp load_raw_document(id) do
    cache_key = "doc:#{id}"
    case Hub.Cache.get(cache_key) do
      {:ok, result} -> result
      :miss ->
        raw_doc =
          from(rd in RawDocument,
            where: rd.id == ^id,
            left_join: pd in assoc(rd, :processed_document),
            left_join: s in assoc(pd, :signals),
            preload: [:clients, processed_document: {pd, signals: s}]
          )
          |> Repo.one!()

        result = {raw_doc, raw_doc.processed_document}
        Hub.Cache.put(cache_key, result, 300_000)
        result
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto py-6 px-6">
      <.link navigate="/" class="text-[13px] inline-block mb-4 hover:underline" style="color: #7c6f5b;">&larr; Back to Feed</.link>

      <h1 class="text-[22px] font-bold mb-1" style="color: #2d2a26; letter-spacing: -0.3px;">
        <%= (@processed && @processed.ai_title) || @raw_document.metadata["topic"] || "Untitled Meeting" %>
      </h1>

      <div class="text-[13px] mb-5" style="color: #a09888;">
        <%= Enum.join(@raw_document.participants, ", ") %>
        &middot;
        <%= format_date(@raw_document.metadata["start_time"] || @raw_document.ingested_at) %>
        <%= unless @processed do %>
          <span class="ml-2 text-[11px] px-2 py-0.5 rounded" style="background: #f0ece4; color: #a09888;">Unprocessed</span>
        <% end %>
      </div>

      <%= if @processed do %>
        <div class="rounded-xl mb-3.5" style="background: #fff; border: 1px solid #e8e5df; padding: 14px 18px;">
          <div class="text-[10px] font-semibold uppercase tracking-widest mb-2" style="color: #a09888;">Summary</div>
          <p class="text-sm leading-relaxed" style="color: #3d3832;"><%= @processed.summary %></p>
        </div>

        <%= if @processed.signals != [] do %>
          <div class="rounded-xl mb-3.5" style="background: #fff; border: 1px solid #e8e5df; padding: 14px 18px;">
            <div class="text-[10px] font-semibold uppercase tracking-widest mb-2.5" style="color: #a09888;">Signals</div>
            <div>
              <div :for={signal <- @processed.signals} class="flex items-start gap-3 py-2" style="border-top: 1px solid #f5f2ed; &:first-child { border-top: none; }">
                <span class={"text-[11px] px-2 py-0.5 rounded font-medium flex-shrink-0 " <> Hub.Signals.style(signal.type)}>
                  <%= Hub.Signals.label(signal.type) %>
                </span>
                <div>
                  <p class="text-sm" style="color: #5c5549;">"<%= signal.content %>"</p>
                  <p class="text-xs mt-0.5" style="color: #a09888;">— <%= signal.speaker %></p>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @processed.action_items != [] do %>
          <div class="rounded-xl mb-3.5" style="background: #fff; border: 1px solid #e8e5df; padding: 14px 18px;">
            <div class="text-[10px] font-semibold uppercase tracking-widest mb-2" style="color: #a09888;">Action Items</div>
            <div :for={item <- @processed.action_items} class="text-sm py-1" style="color: #5c5549;">
              <%= item["text"] %>
              <%= if item["person"] do %><span style="color: #a09888;"> — <%= item["person"] %></span><% end %>
            </div>
          </div>
        <% end %>
      <% end %>

      <div class="rounded-xl" style="background: #fff; border: 1px solid #e8e5df; padding: 14px 18px;">
        <div class="text-[10px] font-semibold uppercase tracking-widest mb-3" style="color: #a09888;">Transcript</div>
        <%= if @messages == [] do %>
          <div class="text-sm whitespace-pre-wrap font-mono" style="color: #5c5549;"><%= @raw_document.content %></div>
        <% else %>
          <.transcript messages={@messages} color_map={@color_map} avatar_map={@avatar_map} />
        <% end %>
      </div>
    </div>
    """
  end

  defp transcript(assigns) do
    groups = group_consecutive(assigns.messages)
    assigns = assign(assigns, :groups, groups)

    ~H"""
    <div class="divide-y" style="border-color: #f0ece4;">
      <div :for={group <- @groups} class="flex gap-3 py-2.5">
        <% avatar = Map.get(@avatar_map, group.speaker) %>
        <div class="flex-shrink-0 pt-0.5">
          <%= if avatar do %>
            <img src={avatar} class="w-8 h-8 rounded-full object-cover" />
          <% else %>
            <div class="w-8 h-8 rounded-full flex items-center justify-center text-[13px] font-semibold" style={"background: #{Hub.Colors.initial_color(group.speaker)}; color: #fff;"}>
              <%= String.first(group.speaker) %>
            </div>
          <% end %>
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-[12px] font-semibold mb-1" style="color: #2d2a26;"><%= group.speaker %></div>
          <div :for={msg <- group.messages} class="text-[13.5px]" style="color: #3d3832; line-height: 1.55;">
            <%= msg.text %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp group_consecutive(messages) do
    messages
    |> Enum.reduce([], fn msg, acc ->
      case acc do
        [%{speaker: speaker} = group | rest] when speaker == msg.speaker ->
          [%{group | messages: group.messages ++ [msg]} | rest]
        _ ->
          [%{speaker: msg.speaker, messages: [msg]} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp build_speaker_maps(messages) do
    speakers = messages |> Enum.map(& &1.speaker) |> Enum.uniq()

    people_data =
      from(p in Person, select: {p.name, %{color: p.color, avatar_url: p.avatar_url}})
      |> Repo.all()
      |> Map.new()

    fallback_count = tuple_size(@fallback_colors)

    {color_map, avatar_map, _} =
      Enum.reduce(speakers, {%{}, %{}, 0}, fn speaker, {colors, avatars, fallback_idx} ->
        person = Map.get(people_data, speaker, %{color: nil, avatar_url: nil})
        avatars = if person.avatar_url, do: Map.put(avatars, speaker, person.avatar_url), else: avatars

        case person.color do
          nil ->
            style = elem(@fallback_colors, rem(fallback_idx, fallback_count))
            {Map.put(colors, speaker, style), avatars, fallback_idx + 1}

          color_name ->
            {bubble, _text} = Hub.Colors.bubble_style(color_name)
            {Map.put(colors, speaker, {bubble, "color: #{Hub.Colors.hex_color(color_name)}"}), avatars, fallback_idx}
        end
      end)

    {color_map, avatar_map}
  end

  defp parse_transcript(nil), do: []
  defp parse_transcript(""), do: []

  defp parse_transcript(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce([], fn line, acc ->
      case Regex.run(@speaker_line, line) do
        [_, speaker, text] ->
          [%{speaker: String.trim(speaker), text: String.trim(text)} | acc]

        nil ->
          case acc do
            [prev | rest] -> [%{prev | text: prev.text <> " " <> String.trim(line)} | rest]
            [] -> acc
          end
      end
    end)
    |> Enum.reverse()
  end
end
