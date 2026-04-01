defmodule HubWeb.PeopleLive do
  use HubWeb, :live_view

  alias Hub.People.Person
  alias Hub.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    people =
      from(p in Person,
        left_join: dp in "document_people", on: dp.person_id == p.id,
        group_by: p.id,
        select: %{id: p.id, name: p.name, email: p.email, conversation_count: count(dp.raw_document_id)},
        order_by: [asc: p.name]
      )
      |> Repo.all()

    {:ok, assign(socket, people: people, page_title: "People")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold text-gray-900 mb-8">People</h1>

      <%= if @people == [] do %>
        <p class="text-gray-500 text-center">No people yet.</p>
      <% else %>
        <div class="bg-white rounded-lg shadow border border-gray-200 divide-y divide-gray-200">
          <.link :for={person <- @people} navigate={"/people/#{person.id}"} class="flex items-center justify-between px-6 py-4 hover:bg-gray-50">
            <div>
              <span class="font-medium text-gray-900"><%= person.name %></span>
              <%= if person.email do %>
                <span class="text-sm text-gray-500 ml-2"><%= person.email %></span>
              <% end %>
            </div>
            <span class="text-sm text-gray-500"><%= person.conversation_count %> conversations</span>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end
end
