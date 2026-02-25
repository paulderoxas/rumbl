defmodule RumblWeb.SessionLive.New do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event(
        "save",
        %{"session" => %{"username" => username, "password" => password}},
        socket
      ) do
    case Accounts.authenticate_by_username_and_pass(username, password) do
      {:ok, user} ->
        {:noreply, push_navigate(socket, to: ~p"/sessions/callback?user_id=#{user.id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Invalid username or password")}
    end
  end
end
