defmodule Hub.Documents.TranscriptChunk do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transcript_chunks" do
    field :content, :string
    field :chunk_index, :integer
    field :start_ms, :integer
    field :end_ms, :integer

    belongs_to :raw_document, Hub.Documents.RawDocument

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:raw_document_id, :content, :chunk_index, :start_ms, :end_ms])
    |> validate_required([:raw_document_id, :content, :chunk_index])
  end
end
