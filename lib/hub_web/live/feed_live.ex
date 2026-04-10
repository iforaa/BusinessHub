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
      ai_step: nil,
      ai_streaming_text: nil,
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
        pid = self()
        user = socket.assigns[:current_user]
        Task.Supervisor.async_nolink(Hub.TaskSupervisor, fn ->
          AiSearch.query(question,
            on_step: fn step -> send(pid, {:ai_step, step}) end,
            on_stream: fn text -> send(pid, {:ai_stream, text}) end,
            user: user
          )
        end, shutdown: 60_000)
        {:noreply, assign(socket, query: query, ai_loading: true, ai_step: "Starting...", ai_answer: nil, search_results: nil, filtered_person: nil)}

      true ->
        {:noreply, assign(socket, search_results: Search.fulltext(query), ai_answer: nil, ai_loading: false, query: query, filtered_person: nil)}
    end
  end

  @impl true
  def handle_info({:ai_step, step}, socket) do
    {:noreply, assign(socket, ai_step: step)}
  end

  def handle_info({:ai_stream, text}, socket) do
    {:noreply, assign(socket, ai_streaming_text: text, ai_loading: false)}
  end

  def handle_info({ref, {:ok, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, ai_answer: result, ai_loading: false, ai_streaming_text: nil)}
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
            <.ai_loading_steps step={@ai_step} />

          <% @ai_streaming_text && !@ai_answer -> %>
            <.ai_streaming_card text={@ai_streaming_text} />

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

  @ai_steps [
    {"embedding", "Embedding your question"},
    {"searching", "Searching across conversations"},
    {"context", "Building context from matches"},
    {"thinking", "Generating answer with AI"},
    {"done", "Complete"}
  ]

  defp ai_loading_steps(assigns) do
    steps = @ai_steps
    current = assigns.step || "embedding"
    current_idx = Enum.find_index(steps, fn {id, _} -> id == current end) || 0
    assigns = assign(assigns, steps: steps, current_idx: current_idx)

    ~H"""
    <div class="rounded-xl p-6" style="background: #fff; border: 1px solid #e8e5df;">
      <div class="space-y-3">
        <div :for={{step_id, step_label} <- @steps} class="flex items-center gap-3">
          <% idx = Enum.find_index(@steps, fn {id, _} -> id == step_id end) %>
          <%= cond do %>
            <% idx < @current_idx -> %>
              <div class="w-5 h-5 rounded-full flex items-center justify-center" style="background: #d4cec2;">
                <svg class="w-3 h-3" style="color: #fff;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="text-sm" style="color: #a09888;"><%= step_label %></span>

            <% idx == @current_idx -> %>
              <div class="w-5 h-5 rounded-full border-2 animate-spin" style="border-color: #e8e5df; border-top-color: #7c6f5b;"></div>
              <span class="text-sm font-medium" style="color: #3d3832;"><%= step_label %></span>

            <% true -> %>
              <div class="w-5 h-5 rounded-full" style="border: 2px solid #e8e5df;"></div>
              <span class="text-sm" style="color: #d4cec2;"><%= step_label %></span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp ai_streaming_card(assigns) do
    ~H"""
    <div class="rounded-xl p-5" style="background: #fff; border: 1px solid #e8e5df;">
      <div class="mb-3">
        <span class="text-[11px] font-semibold px-2.5 py-1 rounded" style="background: #f0ece4; color: #7c6f5b;">AI Answer</span>
        <span class="ml-2 inline-block w-1.5 h-4 animate-pulse rounded-sm" style="background: #7c6f5b;"></span>
      </div>
      <div class="text-sm leading-relaxed whitespace-pre-wrap" style="color: #3d3832;"><%= @text %></div>
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

  @feed_fields [:id, :source, :source_id, :participants, :metadata, :ingested_at, :inserted_at, :updated_at]

  defp load_documents do
    case Hub.Cache.get("feed:documents") do
      {:ok, docs} -> docs
      :miss ->
        docs = fetch_documents()
        Hub.Cache.put("feed:documents", docs, 60_000)
        docs
    end
  end

  defp fetch_documents do
    ids_query =
      from(rd in RawDocument,
        select: rd.id,
        order_by: [desc: fragment("?->>'start_time'", rd.metadata)],
        limit: 50
      )

    from(rd in RawDocument,
      where: rd.id in subquery(ids_query),
      select: struct(rd, ^@feed_fields),
      preload: [processed_document: :signals],
      order_by: [desc: fragment("?->>'start_time'", rd.metadata)]
    )
    |> Repo.all()
  end

  defp load_documents_for_person(person_id) do
    cache_key = "feed:person:#{person_id}"
    case Hub.Cache.get(cache_key) do
      {:ok, docs} -> docs
      :miss ->
        docs = fetch_documents_for_person(person_id)
        Hub.Cache.put(cache_key, docs, 60_000)
        docs
    end
  end

  defp fetch_documents_for_person(person_id) do
    ids_query =
      from(rd in RawDocument,
        join: dp in "document_people", on: dp.raw_document_id == rd.id,
        where: dp.person_id == type(^person_id, :binary_id),
        select: rd.id
      )

    from(rd in RawDocument,
      where: rd.id in subquery(ids_query),
      select: struct(rd, ^@feed_fields),
      preload: [processed_document: :signals],
      order_by: [desc: fragment("?->>'start_time'", rd.metadata)]
    )
    |> Repo.all()
  end

  defp load_people do
    case Hub.Cache.get("people:sidebar") do
      {:ok, people} -> people
      :miss ->
        people = fetch_people()
        Hub.Cache.put("people:sidebar", people, 300_000)
        people
    end
  end

  defp fetch_people do
    from(p in Person,
      left_join: dp in "document_people", on: dp.person_id == p.id,
      group_by: p.id,
      select: %{id: p.id, name: p.name, role: p.role, conversation_count: count(dp.raw_document_id)},
      order_by: [asc: p.name]
    )
    |> Repo.all()
  end
end
