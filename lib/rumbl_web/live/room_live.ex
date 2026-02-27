defmodule RumblWeb.RoomLive do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia

  def mount(%{"code" => code}, session, socket) do
    current_user = get_user_from_session(session)

    case Multimedia.get_room_by_code(code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Room not found or has been closed.")
         |> push_navigate(to: ~p"/videos")}

      room ->
        is_host = current_user && current_user.id == room.host_id
        annotations = Multimedia.list_annotations(room.video)

        # Generate user token for WebSocket authentication
        user_token =
          if current_user do
            Phoenix.Token.sign(RumblWeb.Endpoint, "user socket", current_user.id)
          else
            ""
          end

        socket =
          assign(socket,
            room: room,
            current_user: current_user,
            is_host: is_host,
            annotations: annotations,
            chat_messages: [],
            user_token: user_token
          )

        # Subscribe to room channel events (optional - for debugging/logging)
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Rumbl.PubSub, "room:#{room.code}")
        end

        {:ok, socket}
    end
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end

  def format_time(ms) when is_integer(ms) do
    total = div(ms, 1000)
    minutes = div(total, 60)
    seconds = rem(total, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def format_time(_), do: "0:00"

  def handle_event("leave_room", _params, socket) do
    room = socket.assigns.room
    is_host = socket.assigns.is_host

    # If host, close the room
    case is_host do
      true ->
        Multimedia.close_room(room)

      false ->
        :ok
    end

    {:noreply,
     socket
     |> put_flash(:info, if(is_host, do: "Room closed.", else: "You left the room."))
     |> push_navigate(to: ~p"/videos")}
  end

  def handle_event("submit-annotation-form", %{"body" => body}, socket) do
    current_user = socket.assigns.current_user
    room = socket.assigns.room

    if is_nil(current_user) or body |> String.trim() == "" do
      {:noreply, socket}
    else
      # Save annotation to database
      case Multimedia.annotate_video(current_user, room.video.id, %{body: body, at: 0}) do
        {:ok, annotation} ->
          # Load the user association for display
          annotation = %{annotation | user: current_user}

          # Broadcast to other room members via room channel
          Phoenix.PubSub.broadcast(
            Rumbl.PubSub,
            "room:#{room.code}",
            {:new_annotation, annotation}
          )

          # Update local state and clear form
          {:noreply,
           socket
           |> assign(:annotations, socket.assigns.annotations ++ [annotation])
           |> push_event("clear-annotation-form", %{})}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("delete-annotation", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    room = socket.assigns.room

    case Multimedia.get_annotation!(id) do
      nil ->
        {:noreply, socket}

      annotation ->
        if current_user && current_user.id == annotation.user_id do
          Multimedia.delete_annotation(annotation)

          # Broadcast deletion to other room members
          Phoenix.PubSub.broadcast(
            Rumbl.PubSub,
            "room:#{room.code}",
            {:annotation_deleted, id}
          )

          {:noreply,
           socket
           |> assign(:annotations, Enum.reject(socket.assigns.annotations, &(&1.id == id)))}
        else
          {:noreply, socket}
        end
    end
  rescue
    _ ->
      {:noreply, socket}
  end

  def handle_info({:new_annotation, annotation}, socket) do
    # Add annotation from another room member to our list
    # (skip if we're the one who posted it - already in our list)
    if annotation.user_id != socket.assigns.current_user.id do
      {:noreply, assign(socket, :annotations, socket.assigns.annotations ++ [annotation])}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:annotation_deleted, id}, socket) do
    {:noreply,
     assign(socket, :annotations, Enum.reject(socket.assigns.annotations, &(&1.id == id)))}
  end

  def extract_youtube_id(url) do
    case Regex.run(~r{(?:youtube\.com/watch\?v=|youtu\.be/)([^&#?\s]+)}, url || "") do
      [_, id] -> id
      _ -> ""
    end
  end
end
