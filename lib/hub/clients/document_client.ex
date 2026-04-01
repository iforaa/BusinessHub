defmodule Hub.Clients.DocumentClient do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :binary_id

  schema "document_clients" do
    belongs_to :raw_document, Hub.Documents.RawDocument
    belongs_to :client, Hub.Clients.Client
  end
end
