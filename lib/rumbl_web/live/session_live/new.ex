defmodule RumblWeb.SessionLive.New do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)
    {:ok, assign(socket, current_user: current_user)}
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

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
