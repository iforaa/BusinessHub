defmodule Hub.Pipeline.Merger do
  def merge([single]) do
    %{
      summary: single["summary"],
      action_items: single["action_items"] || [],
      signals: single["signals"] || [],
      client_names: single["client_names"] || []
    }
  end

  def merge(results) do
    %{
      summary: results |> Enum.map(& &1["summary"]) |> Enum.join(" "),
      action_items: results |> Enum.flat_map(& (&1["action_items"] || [])),
      signals: results |> Enum.flat_map(& (&1["signals"] || [])),
      client_names: results |> Enum.flat_map(& (&1["client_names"] || [])) |> Enum.uniq()
    }
  end
end
