defmodule RumblWeb.VideoLive.Show do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia

  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)
    {:ok, assign(socket, current_user: current_user)}
  end

  # Loads the video by :id from the URL (/videos/:id)
  def handle_params(%{"id" => id}, _uri, socket) do
    video = Multimedia.get_video!(id)
    {:noreply, assign(socket, video: video)}
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
