defmodule RumblWeb.VideoLive.Index do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video

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

  def handle_event("join_room", %{"code" => code}, socket) do
    case Multimedia.get_room_by_code(code) do
      nil ->
        {:noreply, put_flash(socket, :error, "Room not found or has been closed.")}

      room ->
        {:noreply, push_navigate(socket, to: ~p"/rooms/#{room.code}")}
    end
  end

  # Reads user_id from the Plug session (written by Auth plug / SessionController)
  # and loads the User from the database
  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end

  def youtube_id(video), do: Video.youtube_id(video)
end
