defmodule Hub.Signals do
  @styles %{
    "bug_report" => "bg-[#f8f0ee] text-[#9a6b5e]",
    "feature_request" => "bg-[#f0f4ee] text-[#6b7f5e]",
    "commitment" => "bg-[#eef0f4] text-[#5e6b7f]",
    "positive_feedback" => "bg-[#f4f2ee] text-[#7f7a5e]",
    "competitor_mention" => "bg-[#f4eef0] text-[#7f5e6b]",
    "churn_signal" => "bg-[#f4eeee] text-[#7f5e5e]",
    "pricing_discussion" => "bg-[#f0ece4] text-[#7c6f5b]",
    "onboarding_issue" => "bg-[#f0ece4] text-[#7c6f5b]"
  }

  @labels %{
    "bug_report" => "Bug",
    "feature_request" => "Feature",
    "commitment" => "Commitment",
    "positive_feedback" => "Positive",
    "competitor_mention" => "Competitor",
    "churn_signal" => "Churn",
    "pricing_discussion" => "Pricing",
    "onboarding_issue" => "Onboarding"
  }

  def style(type), do: Map.get(@styles, type, "bg-[#f0ece4] text-[#7c6f5b]")
  def label(type), do: Map.get(@labels, type, type)
end
