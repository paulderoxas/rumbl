defmodule RumblWeb.UserLive.Index do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)
    users = Accounts.list_users()
    {:ok, assign(socket, users: users, current_user: current_user)}
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
