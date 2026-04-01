defmodule Hub.Clients.Resolver do
  alias Hub.Clients.Client
  alias Hub.Repo

  import Ecto.Query

  def resolve_and_link(_raw_doc, []), do: :ok

  def resolve_and_link(raw_doc, client_names) do
    Enum.each(client_names, fn name ->
      client = find_or_create(name)
      link_document(raw_doc, client)
    end)

    :ok
  end

  defp find_or_create(name) do
    case find_by_name_or_alias(name) do
      nil ->
        {:ok, client} =
          %Client{}
          |> Client.changeset(%{name: name})
          |> Repo.insert(on_conflict: :nothing, conflict_target: :name, returning: true)

        client || Repo.get_by!(Client, name: name)

      client ->
        client
    end
  end

  defp find_by_name_or_alias(name) do
    downcased = String.downcase(name)

    query = from c in Client, where: fragment("lower(?)", c.name) == ^downcased

    case Repo.one(query) do
      nil ->
        alias_query =
          from c in Client,
            where: fragment("EXISTS (SELECT 1 FROM jsonb_array_elements_text(?) AS alias WHERE lower(alias) = ?)", c.aliases, ^downcased)

        Repo.one(alias_query)

      client ->
        client
    end
  end

  defp link_document(raw_doc, client) do
    Repo.insert_all(
      "document_clients",
      [%{raw_document_id: Ecto.UUID.dump!(raw_doc.id), client_id: Ecto.UUID.dump!(client.id)}],
      on_conflict: :nothing
    )
  end
end
