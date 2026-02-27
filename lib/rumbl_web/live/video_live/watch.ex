defmodule RumblWeb.VideoLive.Watch do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video

  def mount(%{"id" => id}, session, socket) do
    current_user = get_user_from_session(session)
    video = Multimedia.get_video!(id)
    annotations = Multimedia.list_annotations(video)

    # Check if user has an active room for this video
    room =
      if current_user do
        Multimedia.get_active_room_for_host_and_video(current_user.id, video.id)
      end

    # Generate a token so the JS channel (video_channel.ex) can authenticate
    # the user over WebSocket. Passed to the template via @user_token.
    user_token =
      if current_user do
        Phoenix.Token.sign(RumblWeb.Endpoint, "user socket", current_user.id)
      end

    {:ok,
     assign(socket,
       video: video,
       annotations: annotations,
       current_user: current_user,
       user_token: user_token,
       room: room
     )}
  end

  # These two helper functions were previously in VideoHTML.
  # They are used directly in watch.html.heex as youtube_id(@video)
  # and format_time(annotation.at). Moving them here makes them
  # available to the template automatically.
  def youtube_id(video), do: Video.youtube_id(video)

  def format_time(ms) when is_integer(ms) do
    total = div(ms, 1000)
    minutes = div(total, 60)
    seconds = rem(total, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def format_time(_), do: "0:00"

  def handle_event("create_room", _params, socket) do
    user = socket.assigns.current_user
    video = socket.assigns.video

    case Multimedia.create_room(user, video) do
      {:ok, room} ->
        {:noreply,
         socket
         |> assign(:room, room)
         |> push_event("room-created", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create room. Please try again.")}
    end
  end

  def handle_event("close_room", _params, socket) do
    room = socket.assigns.room

    case Multimedia.close_room(room) do
      {:ok, _closed_room} ->
        {:noreply,
         socket
         |> assign(:room, nil)
         |> put_flash(:info, "Room closed successfully.")
         |> push_event("hide-create-room-modal", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not close room. Please try again.")}
    end
  end

  def handle_event("show-create-room-modal", _params, socket) do
    {:noreply, push_event(socket, "show-create-room-modal", %{})}
  end

  def handle_event("hide-create-room-modal", _params, socket) do
    {:noreply, push_event(socket, "hide-create-room-modal", %{})}
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
