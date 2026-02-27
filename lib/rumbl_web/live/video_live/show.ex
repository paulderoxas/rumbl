defmodule RumblWeb.VideoLive.Show do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia

  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)
    {:ok, assign(socket, current_user: current_user)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    case Multimedia.get_video(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Video not found.")
         |> push_navigate(to: ~p"/videos")}

      video ->
        {:noreply, assign(socket, video: video)}
    end
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
