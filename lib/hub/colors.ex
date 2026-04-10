defmodule Hub.Colors do
  @palette [
    {"blue", "bg-blue-100 border-blue-300", "bg-blue-50 border-blue-200", "text-blue-700"},
    {"green", "bg-green-100 border-green-300", "bg-green-50 border-green-200", "text-green-700"},
    {"purple", "bg-purple-100 border-purple-300", "bg-purple-50 border-purple-200", "text-purple-700"},
    {"amber", "bg-amber-100 border-amber-300", "bg-amber-50 border-amber-200", "text-amber-700"},
    {"rose", "bg-rose-100 border-rose-300", "bg-rose-50 border-rose-200", "text-rose-700"},
    {"cyan", "bg-cyan-100 border-cyan-300", "bg-cyan-50 border-cyan-200", "text-cyan-700"},
    {"indigo", "bg-indigo-100 border-indigo-300", "bg-indigo-50 border-indigo-200", "text-indigo-700"},
    {"teal", "bg-teal-100 border-teal-300", "bg-teal-50 border-teal-200", "text-teal-700"},
    {"orange", "bg-orange-100 border-orange-300", "bg-orange-50 border-orange-200", "text-orange-700"},
    {"pink", "bg-pink-100 border-pink-300", "bg-pink-50 border-pink-200", "text-pink-700"},
    {"lime", "bg-lime-100 border-lime-300", "bg-lime-50 border-lime-200", "text-lime-700"},
    {"sky", "bg-sky-100 border-sky-300", "bg-sky-50 border-sky-200", "text-sky-700"},
    {"red", "bg-red-100 border-red-300", "bg-red-50 border-red-200", "text-red-700"},
    {"emerald", "bg-emerald-100 border-emerald-300", "bg-emerald-50 border-emerald-200", "text-emerald-700"},
    {"violet", "bg-violet-100 border-violet-300", "bg-violet-50 border-violet-200", "text-violet-700"},
    {"fuchsia", "bg-fuchsia-100 border-fuchsia-300", "bg-fuchsia-50 border-fuchsia-200", "text-fuchsia-700"},
    {"yellow", "bg-yellow-100 border-yellow-300", "bg-yellow-50 border-yellow-200", "text-yellow-700"},
    {"slate", "bg-slate-200 border-slate-400", "bg-slate-50 border-slate-200", "text-slate-700"}
  ]

  def palette, do: @palette

  def bubble_style(color_name) do
    case Enum.find(@palette, fn {name, _, _, _} -> name == color_name end) do
      {_, _, bubble, text} -> {bubble, text}
      nil -> {"bg-gray-50 border-gray-200", "text-gray-600"}
    end
  end

  def swatch_class(color_name) do
    case Enum.find(@palette, fn {name, _, _, _} -> name == color_name end) do
      {_, swatch, _, _} -> swatch
      nil -> "bg-gray-100 border-gray-300"
    end
  end

  @hex_colors %{
    "blue" => "#1d4ed8", "green" => "#15803d", "purple" => "#7e22ce",
    "amber" => "#b45309", "rose" => "#be123c", "cyan" => "#0e7490",
    "indigo" => "#4338ca", "teal" => "#0f766e", "orange" => "#c2410c",
    "pink" => "#be185d", "lime" => "#4d7c0f", "sky" => "#0369a1",
    "red" => "#b91c1c", "emerald" => "#047857", "violet" => "#6d28d9",
    "fuchsia" => "#a21caf", "yellow" => "#a16207", "slate" => "#475569"
  }

  def hex_color(color_name), do: Map.get(@hex_colors, color_name, "#7c6f5b")

  @initial_bg_colors [
    "#8b7355", "#6b8e6b", "#7b6b8e", "#8e7b6b", "#6b7b8e",
    "#8e6b7b", "#6b8e7b", "#7b8e6b", "#856b6b", "#6b7085",
    "#857b6b", "#6b856b", "#7b6b85", "#856b7b", "#6b8585",
    "#85856b", "#6b6b85", "#856b85"
  ]

  def initial_color(name) when is_binary(name) do
    idx = :erlang.phash2(name, length(@initial_bg_colors))
    Enum.at(@initial_bg_colors, idx)
  end

  def initial_color(_), do: "#8b7355"
end
