defmodule Hub.Claude.ClientTest do
  use ExUnit.Case

  alias Hub.Claude.Client

  describe "build_request/2" do
    test "builds correct request body for messages API" do
      body = Client.build_request("Extract signals from this transcript.", system: "You are an analyst.")

      assert body.model =~ "claude"
      assert length(body.messages) == 1
      assert hd(body.messages).role == "user"
      assert hd(body.messages).content == "Extract signals from this transcript."
      assert body.system == "You are an analyst."
    end

    test "includes max_tokens" do
      body = Client.build_request("Hello", max_tokens: 2048)
      assert body.max_tokens == 2048
    end
  end
end
