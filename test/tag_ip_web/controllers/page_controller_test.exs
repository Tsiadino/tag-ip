defmodule TagIpWeb.PageControllerTest do
  use TagIpWeb.ConnCase

  test "GET / redirects to login when unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/login"
  end
end
