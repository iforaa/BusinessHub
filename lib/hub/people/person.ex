defmodule Hub.People.Person do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.RawDocument

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "people" do
    field :name, :string
    field :email, :string
    field :aliases, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :role, :string, default: "unknown"
    field :context, :string, default: ""
    field :color, :string
    field :avatar_url, :string

    many_to_many :raw_documents, RawDocument, join_through: "document_people"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(person, attrs) do
    person
    |> cast(attrs, [:name, :email, :aliases, :metadata, :role, :context, :color, :avatar_url])
    |> unique_constraint(:color)
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
