defmodule RumblWeb.VideoLive.Index do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia

  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)

    if is_nil(current_user) do
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access this page")
       |> push_navigate(to: ~p"/sessions/new")}
    else
      videos = Multimedia.list_user_videos(current_user)
      {:ok, assign(socket, videos: videos, current_user: current_user)}
    end
  end

  # Triggered by phx-click="delete" phx-value-id={video.id} in index.html.heex
  @spec handle_event(<<_::48>>, map(), Phoenix.LiveView.Socket.t()) :: {:noreply, any()}
  def handle_event("delete", %{"id" => id}, socket) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)
    {:ok, _} = Multimedia.delete_video(video)

    # Reload the list after deletion so the table updates
    videos = Multimedia.list_user_videos(socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Video deleted.")
     |> assign(videos: videos)}
  end

  # Reads user_id from the Plug session (written by Auth plug / SessionController)
  # and loads the User from the database
  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
