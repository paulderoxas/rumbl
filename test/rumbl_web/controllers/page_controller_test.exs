defmodule RumblWeb.PageControllerTest do
  use RumblWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    # landing page now uses a hero headline
    assert html_response(conn, 200) =~ "Watch together"
  end
end
