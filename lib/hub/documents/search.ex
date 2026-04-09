defmodule Hub.Documents.Search do
  import Ecto.Query

  alias Hub.Documents.RawDocument
  alias Hub.Repo

  @mark_start "[[MARK_START]]"
  @mark_end "[[MARK_END]]"
  @headline_opts "MaxFragments=3,MaxWords=30,MinWords=15,StartSel=#{@mark_start},StopSel=#{@mark_end}"

  def fulltext(query) when byte_size(query) == 0, do: []

  def fulltext(query) do
    tsquery = to_tsquery(query)
    if tsquery == "", do: [], else: execute_search(tsquery)
  end

  defp execute_search(tsquery) do
    from(rd in RawDocument,
      where: fragment("search_vector @@ to_tsquery('english', ?)", ^tsquery),
      select: %{
        id: rd.id,
        metadata: rd.metadata,
        participants: rd.participants,
        ingested_at: rd.ingested_at,
        excerpts: fragment(
          "ts_headline('english', ?, to_tsquery('english', ?), ?)",
          rd.content, ^tsquery, ^@headline_opts
        ),
        rank: fragment("ts_rank(search_vector, to_tsquery('english', ?))", ^tsquery)
      },
      order_by: [desc: fragment("?->>'start_time'", rd.metadata)],
      limit: 30
    )
    |> Repo.all()
    |> Enum.map(fn result ->
      %{result | excerpts: split_excerpts(result.excerpts)}
    end)
  end

  defp split_excerpts(nil), do: []
  defp split_excerpts(headline) do
    headline
    |> String.split(" ... ")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&sanitize_excerpt/1)
  end

  defp sanitize_excerpt(excerpt) do
    excerpt
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(@mark_start, "<mark>")
    |> String.replace(@mark_end, "</mark>")
  end

  defp to_tsquery(input) do
    words =
      input
      |> String.replace(~r/[^\w\s]/, " ")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reject(&(&1 == ""))

    case words do
      [] -> ""
      words ->
        words
        |> Enum.map(fn word -> word <> ":*" end)
        |> Enum.join(" & ")
    end
  end
end
