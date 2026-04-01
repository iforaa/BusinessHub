defmodule HubWeb.PersonLive do
  use HubWeb, :live_view

  import HubWeb.Components.DocumentCard

  alias Hub.People.Person
  alias Hub.Documents.ProcessedDocument
  alias Hub.Repo
  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    person = Repo.get!(Person, id)

    documents =
      from(pd in ProcessedDocument,
        join: rd in assoc(pd, :raw_document),
        join: dp in "document_people", on: dp.raw_document_id == rd.id,
        where: dp.person_id == ^id,
        preload: [:signals, raw_document: rd],
        order_by: [desc: pd.processed_at]
      )
      |> Repo.all()

    {:ok, assign(socket, person: person, documents: documents, page_title: person.name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <.link navigate="/people" class="text-blue-600 hover:underline mb-4 inline-block">&larr; Back to People</.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-2"><%= @person.name %></h1>

      <div class="text-sm text-gray-600 mb-8">
        <%= if @person.email do %><%= @person.email %> &middot; <% end %>
        <%= length(@documents) %> conversations
      </div>

      <%= if @documents == [] do %>
        <p class="text-gray-500">No conversations with this person yet.</p>
      <% else %>
        <.document_card :for={doc <- @documents} document={doc} />
      <% end %>
    </div>
    """
  end
end
