defmodule RumblWeb.UserLive.Index do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    {:ok, assign(socket, users: users)}
  end
end
