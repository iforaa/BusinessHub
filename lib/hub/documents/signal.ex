defmodule Hub.Documents.Signal do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hub.Documents.ProcessedDocument

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "signals" do
    belongs_to :processed_document, ProcessedDocument

    field :type, :string
    field :content, :string
    field :speaker, :string
    field :confidence, :float
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, [:processed_document_id, :type, :content, :speaker, :confidence, :metadata])
    |> validate_required([:processed_document_id, :type, :content])
    |> foreign_key_constraint(:processed_document_id)
  end

end
