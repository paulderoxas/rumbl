defmodule RumblWeb.UserLive.Show do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  # handle_params runs after mount and whenever the URL changes.
  # It's the right place to read URL params like :id.
  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)
    {:ok, assign(socket, current_user: current_user)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    user = Accounts.get_user!(id)
    {:noreply, assign(socket, user: user)}
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
