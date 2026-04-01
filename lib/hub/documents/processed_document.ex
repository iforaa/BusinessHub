defmodule Hub.Documents.ProcessedDocument do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.{RawDocument, Signal}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "processed_documents" do
    belongs_to :raw_document, RawDocument
    has_many :signals, Signal

    field :summary, :string
    field :action_items, {:array, :map}, default: []
    field :model, :string
    field :prompt_version, :string
    field :processed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(processed_document, attrs) do
    processed_document
    |> cast(attrs, [:raw_document_id, :summary, :action_items, :model, :prompt_version, :processed_at])
    |> validate_required([:raw_document_id])
    |> foreign_key_constraint(:raw_document_id)
  end
end
