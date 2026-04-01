defmodule Hub.Documents.RawDocument do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "raw_documents" do
    field :source, :string
    field :source_id, :string
    field :content, :string
    field :segments, {:array, :map}, default: []
    field :participants, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :ingested_at, :utc_datetime_usec

    many_to_many :clients, Hub.Clients.Client, join_through: "document_clients"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(raw_document, attrs) do
    raw_document
    |> cast(attrs, [:source, :source_id, :content, :segments, :participants, :metadata, :ingested_at])
    |> validate_required([:source, :source_id, :content])
    |> unique_constraint(:source_id, name: :raw_documents_source_source_id_index)
  end
end
