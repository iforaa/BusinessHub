defmodule HubWeb.Helpers do
  @doc "Formats a DateTime or ISO 8601 string for display."
  def format_date(nil), do: ""

  def format_date(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%b %d, %Y %H:%M")
      _ -> datetime
    end
  end

  def format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end

  def markdown(text) do
    case Earmark.as_html(text) do
      {:ok, html, _} -> html
      {:error, _, _} -> text
    end
  end
end
