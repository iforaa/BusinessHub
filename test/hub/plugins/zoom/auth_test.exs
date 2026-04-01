defmodule Hub.Plugins.Zoom.AuthTest do
  use ExUnit.Case

  alias Hub.Plugins.Zoom.Auth

  describe "token management" do
    test "get_token/0 returns error when not configured" do
      assert {:error, _reason} = Auth.fetch_token(%{
        account_id: "fake",
        client_id: "fake",
        client_secret: "fake"
      })
    end

    test "build_auth_header/2 encodes credentials correctly" do
      header = Auth.build_auth_header("my_client_id", "my_client_secret")
      expected = Base.encode64("my_client_id:my_client_secret")
      assert header == "Basic #{expected}"
    end
  end
end
