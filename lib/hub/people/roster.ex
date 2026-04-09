defmodule Hub.People.Roster do
  alias Hub.People.Person
  alias Hub.Repo

  import Ecto.Query

  def employees_prompt do
    load_by_role("employee") |> format()
  end

  def clients_prompt do
    load_by_role("client") |> format()
  end

  defp load_by_role(role) do
    from(p in Person, where: p.role == ^role, select: %{name: p.name, context: p.context})
    |> Repo.all()
  end

  defp format([]), do: "(none configured)"
  defp format(people) do
    people
    |> Enum.map(fn p ->
      if p.context != "", do: "- #{p.name} (#{p.context})", else: "- #{p.name}"
    end)
    |> Enum.join("\n")
  end
end
