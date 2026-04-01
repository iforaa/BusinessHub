defmodule Hub.People.Resolver do
  alias Hub.People.Person
  alias Hub.Repo
  import Ecto.Query

  def resolve_and_link(_raw_doc, []), do: :ok

  def resolve_and_link(raw_doc, participant_names) do
    Enum.each(participant_names, fn name ->
      person = find_or_create(name)
      link_document(raw_doc, person)
    end)
    :ok
  end

  defp find_or_create(name) do
    case find_by_name_or_alias(name) do
      nil ->
        {:ok, person} =
          %Person{}
          |> Person.changeset(%{name: name})
          |> Repo.insert(on_conflict: :nothing, conflict_target: :name, returning: true)
        person || Repo.get_by!(Person, name: name)
      person ->
        person
    end
  end

  defp find_by_name_or_alias(name) do
    downcased = String.downcase(name)
    query = from p in Person, where: fragment("lower(?)", p.name) == ^downcased

    case Repo.one(query) do
      nil ->
        alias_query =
          from p in Person,
            where: fragment("EXISTS (SELECT 1 FROM jsonb_array_elements_text(?) AS alias WHERE lower(alias) = ?)", p.aliases, ^downcased)
        Repo.one(alias_query)
      person ->
        person
    end
  end

  defp link_document(raw_doc, person) do
    Repo.insert_all(
      "document_people",
      [%{raw_document_id: Ecto.UUID.dump!(raw_doc.id), person_id: Ecto.UUID.dump!(person.id)}],
      on_conflict: :nothing
    )
  end
end
