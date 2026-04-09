defmodule HubWeb.PeopleLive do
  use HubWeb, :live_view

  alias Hub.People.Person
  alias Hub.Repo

  import Ecto.Query

  @roles ~w(unknown employee client external)

  @colors Hub.Colors.palette()

  @impl true
  def mount(_params, _session, socket) do
    people = load_people()
    taken_colors = people |> Enum.map(& &1.color) |> Enum.reject(&is_nil/1) |> MapSet.new()

    {:ok, assign(socket, people: people, taken_colors: taken_colors, open_picker: nil, page_title: "People")}
  end

  @impl true
  def handle_event("update_role", %{"person_id" => id, "role" => role}, socket) when role in @roles do
    update_person(id, %{role: role})
    {:noreply, reload_people(socket)}
  end

  def handle_event("update_context", %{"person_id" => id, "context" => context}, socket) do
    update_person(id, %{context: String.trim(context)})
    {:noreply, socket}
  end

  def handle_event("toggle_picker", %{"person-id" => id}, socket) do
    new_id = if socket.assigns.open_picker == id, do: nil, else: id
    {:noreply, assign(socket, open_picker: new_id)}
  end

  def handle_event("set_color", %{"person-id" => id, "color" => color}, socket) do
    person = Repo.get!(Person, id)
    new_color = if person.color == color, do: nil, else: color
    update_person(id, %{color: new_color})
    {:noreply, reload_people(socket) |> assign(open_picker: nil)}
  end

  defp update_person(id, attrs) do
    Repo.get!(Person, id)
    |> Person.changeset(attrs)
    |> Repo.update!()
  end

  defp reload_people(socket) do
    people = load_people()
    taken_colors = people |> Enum.map(& &1.color) |> Enum.reject(&is_nil/1) |> MapSet.new()
    assign(socket, people: people, taken_colors: taken_colors)
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, roles: @roles, colors: @colors)

    ~H"""
    <div class="max-w-4xl mx-auto py-6 px-6">
      <.link navigate="/" class="text-[13px] inline-block mb-4 hover:underline" style="color: #7c6f5b;">&larr; Back to Feed</.link>

      <h1 class="text-[22px] font-bold mb-5" style="color: #2d2a26; letter-spacing: -0.3px;">People</h1>

      <div class="rounded-xl overflow-hidden" style="background: #fff; border: 1px solid #e8e5df;">
        <table class="w-full">
          <thead style="background: #faf8f5; border-bottom: 1px solid #e8e5df;">
            <tr>
              <th class="px-4 py-2.5 text-left text-[10px] font-semibold uppercase tracking-widest w-10" style="color: #a09888;">Color</th>
              <th class="px-4 py-2.5 text-left text-[10px] font-semibold uppercase tracking-widest" style="color: #a09888;">Name</th>
              <th class="px-4 py-2.5 text-left text-[10px] font-semibold uppercase tracking-widest w-28" style="color: #a09888;">Role</th>
              <th class="px-4 py-2.5 text-left text-[10px] font-semibold uppercase tracking-widest" style="color: #a09888;">Context</th>
              <th class="px-4 py-2.5 text-right text-[10px] font-semibold uppercase tracking-widest w-14" style="color: #a09888;">Docs</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={person <- @people} style="border-top: 1px solid #f0ece4;">
              <td class="px-4 py-2.5">
                <div class="relative">
                  <button
                    phx-click="toggle_picker"
                    phx-value-person-id={person.id}
                    class={"w-5 h-5 rounded-full border-2 cursor-pointer " <> color_swatch(person.color)}
                  />
                  <%= if @open_picker == person.id do %>
                    <div class="absolute z-10 top-7 left-0 rounded-lg p-2 flex gap-1 flex-wrap w-40" style="background: #fff; border: 1px solid #e8e5df; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
                      <button
                        :for={{name, swatch_class, _, _} <- @colors}
                        phx-click="set_color"
                        phx-value-person-id={person.id}
                        phx-value-color={name}
                        disabled={name != person.color and MapSet.member?(@taken_colors, name)}
                        class={"w-5 h-5 rounded-full border-2 " <> swatch_class <>
                          if(name == person.color, do: " ring-2 ring-offset-1 ring-gray-400", else: "") <>
                          if(name != person.color and MapSet.member?(@taken_colors, name), do: " opacity-20 cursor-not-allowed", else: " cursor-pointer hover:scale-110 transition-transform")}
                      />
                    </div>
                  <% end %>
                </div>
              </td>
              <td class="px-4 py-2.5 text-[13px] font-medium" style="color: #2d2a26;"><%= person.name %></td>
              <td class="px-4 py-2.5">
                <form phx-change="update_role">
                  <input type="hidden" name="person_id" value={person.id} />
                  <select
                    name="role"
                    class={"text-[11px] rounded px-2 py-1 border appearance-none " <> role_color(person.role)}
                  >
                    <option :for={role <- @roles} value={role} selected={role == person.role}>
                      <%= String.capitalize(role) %>
                    </option>
                  </select>
                </form>
              </td>
              <td class="px-4 py-2.5">
                <form phx-change="update_context">
                  <input type="hidden" name="person_id" value={person.id} />
                  <input
                    type="text"
                    name="context"
                    value={person.context}
                    placeholder="e.g. CTO, manages mobile team"
                    phx-debounce="500"
                    class="w-full text-[13px] border-0 border-b border-transparent focus:border-[#c4b89c] focus:ring-0 px-0 py-1 bg-transparent"
                    style="color: #5c5549;"
                  />
                </form>
              </td>
              <td class="px-4 py-2.5 text-[12px] text-right" style="color: #b5aa9a;"><%= person.doc_count %></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp color_swatch(nil), do: "bg-gray-100 border-gray-300"
  defp color_swatch(color), do: Hub.Colors.swatch_class(color)

  defp role_color("employee"), do: "bg-[#eef0f4] text-[#5e6b7f] border-[#d8dde8]"
  defp role_color("client"), do: "bg-[#f0f4ee] text-[#6b7f5e] border-[#d8e8d8]"
  defp role_color("external"), do: "bg-[#f4eef0] text-[#7f5e6b] border-[#e8d8dd]"
  defp role_color(_), do: "bg-[#f0ece4] text-[#7c6f5b] border-[#e8e2d4]"

  defp load_people do
    from(p in Person,
      left_join: dp in "document_people", on: dp.person_id == p.id,
      group_by: p.id,
      select: %{id: p.id, name: p.name, role: p.role, context: p.context, color: p.color, doc_count: count(dp.raw_document_id)},
      order_by: [asc: p.name]
    )
    |> Repo.all()
  end
end
