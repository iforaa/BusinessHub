defmodule HubWeb.FeedLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard
  import HubWeb.Helpers, only: [format_date: 1, markdown: 1]

  alias Hub.Documents.{AiSearch, RawDocument, Search}
  alias Hub.People.Person
  alias Hub.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hub.PubSub, "documents")
    end

    people = load_people()
    grouped = group_people(people)

    {:ok, assign(socket,
      documents: [],
      search_results: nil,
      ai_answer: nil,
      ai_loading: false,
      people: people,
      people_grouped: grouped,
      people_map: Map.new(people, &{&1.name, &1.id}),
      query: "",
      filtered_person: nil,
      page_title: "Feed"
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""

    cond do
      query == "" ->
        {:noreply, assign(socket, search_results: nil, ai_answer: nil, ai_loading: false, query: "", documents: load_documents())}

      String.starts_with?(query, "!") ->
        question = String.trim_leading(query, "!")
        Task.Supervisor.async_nolink(Hub.TaskSupervisor, fn ->
          AiSearch.query(question)
        end, shutdown: 30_000)
        {:noreply, assign(socket, query: query, ai_loading: true, ai_answer: nil, search_results: nil, filtered_person: nil)}

      true ->
        {:noreply, assign(socket, search_results: Search.fulltext(query), ai_answer: nil, ai_loading: false, query: query, filtered_person: nil)}
    end
  end

  @impl true
  def handle_info({ref, {:ok, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, ai_answer: result, ai_loading: false)}
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, ai_answer: %{answer: "Error: #{inspect(reason)}", sources: []}, ai_loading: false)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, ai_answer: %{answer: "Request failed. Please try again.", sources: []}, ai_loading: false)}
  end

  def handle_info({:document_processed, _doc_id}, socket) do
    if socket.assigns.query == "" and socket.assigns.filtered_person == nil do
      {:noreply, assign(socket, documents: load_documents())}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"q" => raw_query}, socket) do
    query = String.trim(raw_query)

    cond do
      query == "" ->
        {:noreply, push_patch(socket, to: "/")}

      String.starts_with?(query, "!") ->
        {:noreply, assign(socket, query: query)}

      true ->
        {:noreply, push_patch(socket, to: "/?q=#{URI.encode_www_form(query)}", replace: true)}
    end
  end

  def handle_event("submit_search", %{"q" => raw_query}, socket) do
    query = String.trim(raw_query)
    if query != "" do
      {:noreply, push_patch(socket, to: "/?q=#{URI.encode_www_form(query)}")}
    else
      {:noreply, push_patch(socket, to: "/")}
    end
  end

  def handle_event("filter_person", %{"id" => person_id}, socket) do
    if socket.assigns.filtered_person && socket.assigns.filtered_person.id == person_id do
      {:noreply,
        socket
        |> assign(documents: load_documents(), filtered_person: nil, search_results: nil, query: "")
        |> push_event("clear-search", %{})}
    else
      person = Enum.find(socket.assigns.people, &(&1.id == person_id))
      {:noreply,
        socket
        |> assign(documents: load_documents_for_person(person_id), filtered_person: person, search_results: nil, query: "")
        |> push_event("clear-search", %{})}
    end
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply,
      socket
      |> assign(documents: load_documents(), filtered_person: nil, search_results: nil, query: "")
      |> push_event("clear-search", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-6 px-6 flex gap-6">
      <aside class="w-48 flex-shrink-0">
        <%= for {group_label, group_people} <- @people_grouped do %>
          <%= if group_people != [] do %>
            <div class="mb-5">
              <div class="text-[10px] font-semibold uppercase tracking-widest px-2 mb-1.5" style="color: #a09888;"><%= group_label %></div>
              <button
                :for={person <- group_people}
                phx-click="filter_person"
                phx-value-id={person.id}
                class="flex items-center justify-between w-full px-2 py-1.5 rounded-md text-[13px] text-left transition-all"
                style={"color: #{if @filtered_person && @filtered_person.id == person.id, do: "#2d2a26", else: "#5c5549"}; background: #{if @filtered_person && @filtered_person.id == person.id, do: "#fff", else: "transparent"}; #{if @filtered_person && @filtered_person.id == person.id, do: "box-shadow: 0 1px 3px rgba(0,0,0,0.08); font-weight: 500;", else: ""}"}
              >
                <span class="truncate"><%= person.name %></span>
                <span class="text-[11px]" style="color: #b5aa9a;"><%= person.conversation_count %></span>
              </button>
            </div>
          <% end %>
        <% end %>
      </aside>

      <div class="flex-1 min-w-0">
        <form phx-change="search" phx-submit="submit_search" class="mb-5">
          <input
            type="text"
            id="search-input"
            name="q"
            value={@query}
            placeholder="Search transcripts... (prefix with ! for AI)"
            autocomplete="off"
            class="w-full rounded-xl px-4 py-2.5 text-sm outline-none transition-all"
            style="background: #fff; border: 1px solid #e8e5df; color: #2d2a26;"
            onfocus="this.style.borderColor='#c4b89c'; this.style.boxShadow='0 0 0 3px rgba(196,184,156,0.15)'"
            onblur="this.style.borderColor='#e8e5df'; this.style.boxShadow='none'"
          />
        </form>

        <%= if @filtered_person do %>
          <div class="flex items-center gap-2 mb-4">
            <span class="text-sm" style="color: #5c5549;">Showing conversations with</span>
            <span class="inline-flex items-center gap-1 text-sm font-medium px-2.5 py-0.5 rounded-full" style="background: #f0ece4; color: #5c5549;">
              <%= @filtered_person.name %>
              <button phx-click="clear_filter" class="ml-1" style="color: #7c6f5b;">&times;</button>
            </span>
          </div>
        <% end %>

        <%= cond do %>
          <% @ai_loading -> %>
            <div class="text-center py-12">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-2" style="border-color: #e8e5df; border-top-color: #a09888;"></div>
              <p class="text-sm mt-3" style="color: #a09888;">Thinking...</p>
            </div>

          <% @ai_answer -> %>
            <.ai_answer_card answer={@ai_answer} />

          <% @search_results -> %>
            <.search_results results={@search_results} query={@query} />

          <% true -> %>
            <.feed documents={@documents} people_map={@people_map} filtered_person={@filtered_person} />
        <% end %>
      </div>
    </div>
    """
  end

  defp ai_answer_card(assigns) do
    ~H"""
    <div class="rounded-xl p-5" style="background: #fff; border: 1px solid #e8e5df;">
      <div class="mb-3">
        <span class="text-[11px] font-semibold px-2.5 py-1 rounded" style="background: #f0ece4; color: #7c6f5b;">AI Answer</span>
      </div>
      <div class="prose-hub text-sm leading-relaxed" style="color: #3d3832;"><%= raw(markdown(@answer.answer)) %></div>
      <%= if @answer.sources != [] do %>
        <div class="mt-4 pt-3" style="border-top: 1px solid #f0ece4;">
          <div class="text-[11px] mb-1.5" style="color: #a09888;">Sources</div>
          <div class="flex flex-wrap gap-x-3 gap-y-1">
            <.link
              :for={source <- @answer.sources}
              navigate={"/documents/raw/#{source.id}"}
              class="text-xs hover:underline"
              style="color: #7c6f5b;"
            >
              [<%= source.index %>] <%= source.topic %> · <%= format_date(source.start_time) %>
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp search_results(assigns) do
    ~H"""
    <div class="mb-4">
      <span class="text-[13px]" style="color: #a09888;"><%= length(@results) %> result(s) for "<%= @query %>"</span>
    </div>

    <%= if @results == [] do %>
      <div class="text-center py-12" style="color: #a09888;">
        <p class="text-lg">No results found</p>
      </div>
    <% else %>
      <div class="space-y-2.5">
        <.search_result_card :for={result <- @results} result={result} />
      </div>
    <% end %>
    """
  end

  defp search_result_card(assigns) do
    ~H"""
    <.link navigate={"/documents/raw/#{@result.id}"} class="block">
      <div class="rounded-xl overflow-hidden transition-all" style="background: #fff; border: 1px solid #e8e5df;" onmouseover="this.style.borderColor='#d4cdc0'; this.style.boxShadow='0 2px 8px rgba(0,0,0,0.04)'" onmouseout="this.style.borderColor='#e8e5df'; this.style.boxShadow='none'">
        <div class="px-4 py-2" style="background: #faf8f5; border-bottom: 1px solid #f0ece4;">
          <span class="text-xs" style="color: #a09888;">
            <%= @result.metadata["topic"] || "Untitled Meeting" %>
            <span class="mx-1">&middot;</span>
            <%= format_date(@result.metadata["start_time"] || @result.ingested_at) %>
            <span class="mx-1">&middot;</span>
            <%= Enum.join(@result.participants, ", ") %>
          </span>
        </div>
        <div class="px-4 py-1">
          <div :for={excerpt <- @result.excerpts} class="text-sm leading-relaxed py-2" style="color: #5c5549; border-top: 1px dashed #e8e5df; first:border-top-0;">
            <%= raw(excerpt) %>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  defp feed(assigns) do
    ~H"""
    <%= if @documents == [] do %>
      <div class="text-center py-12" style="color: #a09888;">
        <%= if @filtered_person do %>
          <p class="text-lg">No results found</p>
        <% else %>
          <p class="text-lg">No transcripts yet</p>
          <p class="text-sm mt-2">Transcripts will appear here once meetings are ingested.</p>
        <% end %>
      </div>
    <% else %>
      <div>
        <.document_card :for={doc <- @documents} document={doc} people_map={@people_map} />
      </div>
    <% end %>
    """
  end

  defp group_people(people) do
    grouped = Enum.group_by(people, fn p -> p.role end)
    [
      {"Team", Map.get(grouped, "employee", [])},
      {"Clients", Map.get(grouped, "client", [])},
      {"Other", Map.get(grouped, "external", []) ++ Map.get(grouped, "unknown", [])}
    ]
  end

  defp load_documents do
    from(rd in RawDocument,
      left_join: pd in assoc(rd, :processed_document),
      left_join: s in assoc(pd, :signals),
      preload: [processed_document: {pd, signals: s}],
      order_by: [desc: fragment("?->>'start_time'", rd.metadata)],
      limit: 50
    )
    |> Repo.all()
  end

  defp load_documents_for_person(person_id) do
    from(rd in RawDocument,
      join: dp in "document_people", on: dp.raw_document_id == rd.id,
      left_join: pd in assoc(rd, :processed_document),
      left_join: s in assoc(pd, :signals),
      where: dp.person_id == type(^person_id, :binary_id),
      preload: [processed_document: {pd, signals: s}],
      order_by: [desc: fragment("?->>'start_time'", rd.metadata)]
    )
    |> Repo.all()
  end

  defp load_people do
    from(p in Person,
      left_join: dp in "document_people", on: dp.person_id == p.id,
      group_by: p.id,
      select: %{id: p.id, name: p.name, role: p.role, conversation_count: count(dp.raw_document_id)},
      order_by: [asc: p.name]
    )
    |> Repo.all()
  end
end
