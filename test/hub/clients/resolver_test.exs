defmodule Hub.Clients.ResolverTest do
  use Hub.DataCase

  alias Hub.Clients.{Client, Resolver}
  alias Hub.Documents.RawDocument

  describe "resolve_and_link/2" do
    test "creates new client and links to document" do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-1", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Sawyer Creek"])

      client = Repo.get_by!(Client, name: "Sawyer Creek")
      assert client

      linked = raw_doc |> Repo.preload(:clients) |> Map.get(:clients)
      assert length(linked) == 1
      assert hd(linked).id == client.id
    end

    test "matches existing client by name" do
      {:ok, existing} = %Client{} |> Client.changeset(%{name: "Pine Valley"}) |> Repo.insert()

      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-2", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Pine Valley"])
      assert Repo.aggregate(Client, :count) == 1

      linked = raw_doc |> Repo.preload(:clients) |> Map.get(:clients)
      assert hd(linked).id == existing.id
    end

    test "matches by alias" do
      {:ok, _} = %Client{} |> Client.changeset(%{name: "Sawyer Creek Golf Club", aliases: ["Sawyer Creek"]}) |> Repo.insert()

      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-3", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, ["Sawyer Creek"])
      assert Repo.aggregate(Client, :count) == 1
    end

    test "does nothing for empty client names" do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{source: "zoom", source_id: "res-4", content: "text", segments: [], participants: [], metadata: %{}})
        |> Repo.insert()

      assert :ok = Resolver.resolve_and_link(raw_doc, [])
    end
  end
end
