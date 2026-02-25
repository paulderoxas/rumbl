defmodule RumblWeb.UserLive.Show do
  use RumblWeb, :live_view

  alias Rumbl.Accounts

  # handle_params runs after mount and whenever the URL changes.
  # It's the right place to read URL params like :id.
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    user = Accounts.get_user!(id)
    {:noreply, assign(socket, user: user)}
  end
end
