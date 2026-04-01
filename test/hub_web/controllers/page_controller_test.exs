defmodule HubWeb.PageControllerTest do
  use HubWeb.ConnCase

  test "GET / redirects to LiveView feed", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Feed"
  end
end
