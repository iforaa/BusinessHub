defmodule HubWeb.ZoomWebhookControllerTest do
  use HubWeb.ConnCase

  @fixture_path "test/support/fixtures/zoom_webhook_payload.json"

  describe "POST /webhooks/zoom" do
    test "returns 200 and enqueues job for valid transcript_completed event", %{conn: conn} do
      payload = @fixture_path |> File.read!() |> Jason.decode!()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert_enqueued(worker: Hub.Plugins.Zoom.FetchWorker)
    end

    test "responds to Zoom URL validation challenge", %{conn: conn} do
      payload = %{
        "event" => "endpoint.url_validation",
        "payload" => %{
          "plainToken" => "test-token-123"
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      response = json_response(conn, 200)
      assert response["plainToken"] == "test-token-123"
      assert is_binary(response["encryptedToken"])
    end

    test "returns 400 for unknown event", %{conn: conn} do
      payload = %{"event" => "unknown.event", "payload" => %{}}

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/zoom", payload)

      assert json_response(conn, 400) == %{"error" => "unhandled event"}
    end
  end
end
