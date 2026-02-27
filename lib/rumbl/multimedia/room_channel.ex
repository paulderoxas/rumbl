defmodule RumblWeb.RoomChannel do
  use RumblWeb, :channel

  alias Rumbl.{Accounts, Multimedia}

  @impl true
  def join("room:" <> code, _params, socket) do
    case Multimedia.get_room_by_code(code) do
      nil ->
        {:error, %{reason: "Room not found or closed"}}

      room ->
        {:ok, %{room_code: code, video: %{url: room.video.url, title: room.video.title}},
         assign(socket, room_code: code, room: room)}
    end
  end

  # Host controls — play/pause/seek — broadcast to all guests
  @impl true
  def handle_in("playback", %{"action" => action, "time" => time}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    if user.id == socket.assigns.room.host_id do
      broadcast!(socket, "playback", %{action: action, time: time})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Only the host can control playback"}}, socket}
    end
  end

  # Chat message — broadcast to all in room
  @impl true
  def handle_in("chat_message", %{"body" => body}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    if String.trim(body) != "" do
      broadcast!(socket, "chat_message", %{
        user: %{id: user.id, username: user.username},
        body: String.trim(body),
        at: System.system_time(:millisecond)
      })
    end

    {:noreply, socket}
  end

  # Host closes the room
  @impl true
  def handle_in("close_room", _params, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    if user.id == socket.assigns.room.host_id do
      Multimedia.close_room(socket.assigns.room)
      broadcast!(socket, "room_closed", %{})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Only the host can close the room"}}, socket}
    end
  end

  # Guest requests current playback state (on join)
  @impl true
  def handle_in("request_sync", _params, socket) do
    broadcast!(socket, "sync_requested", %{})
    {:noreply, socket}
  end

  # Host responds to sync request
  @impl true
  def handle_in("sync_response", %{"time" => time, "paused" => paused}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    if user.id == socket.assigns.room.host_id do
      broadcast_from!(socket, "playback", %{
        action: if(paused, do: "pause", else: "play"),
        time: time
      })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
