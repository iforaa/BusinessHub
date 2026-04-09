defmodule HubWeb.Components.SignalBadge do
  use Phoenix.Component

  @colors %{
    "feature_request" => "bg-blue-100 text-blue-800",
    "bug_report" => "bg-red-100 text-red-800",
    "competitor_mention" => "bg-purple-100 text-purple-800",
    "churn_signal" => "bg-orange-100 text-orange-800",
    "commitment" => "bg-yellow-100 text-yellow-800",
    "positive_feedback" => "bg-green-100 text-green-800"
  }

  @labels %{
    "feature_request" => "Feature",
    "bug_report" => "Bug Report",
    "competitor_mention" => "Competitor",
    "churn_signal" => "Churn Risk",
    "commitment" => "Commitment",
    "positive_feedback" => "Positive"
  }

  attr :type, :string, required: true
  attr :class, :string, default: ""

  def signal_badge(assigns) do
    assigns =
      assigns
      |> assign(:color, Map.get(@colors, assigns.type, "bg-gray-100 text-gray-800"))
      |> assign(:label, Map.get(@labels, assigns.type, assigns.type))

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{@color} #{@class}"} data-type={@type}>
      <%= @label %>
    </span>
    """
  end
end
