defmodule Hub.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.RawDocument

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clients" do
    field :name, :string
    field :aliases, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    many_to_many :raw_documents, RawDocument, join_through: "document_clients"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :aliases, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
