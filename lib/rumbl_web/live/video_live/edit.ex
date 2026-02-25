defmodule RumblWeb.VideoLive.Edit do
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
      {:ok, assign(socket, current_user: current_user)}
    end
  end

  # handle_params loads the video using the :id from the URL (/videos/:id/edit)
  # It runs after mount and is the right place for URL-dependent data loading
  def handle_params(%{"id" => id}, _uri, socket) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)
    changeset = Multimedia.change_video(video)
    categories = Multimedia.category_options()

    {:noreply,
     assign(socket,
       video: video,
       changeset: changeset,
       categories: categories
     )}
  end

  # Live validation on every keystroke (phx-change="validate")
  def handle_event("validate", %{"video" => video_params}, socket) do
    changeset =
      socket.assigns.video
      |> Multimedia.change_video(video_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  # Form submission (phx-submit="save")
  def handle_event("save", %{"video" => video_params}, socket) do
    case Multimedia.update_video(socket.assigns.video, video_params) do
      {:ok, video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Video updated successfully.")
         |> push_navigate(to: ~p"/videos/#{video.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # Delete button (phx-click="delete" phx-value-id={@video.id} in edit.html.heex)
  def handle_event("delete", %{"id" => id}, socket) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)
    {:ok, _} = Multimedia.delete_video(video)

    {:noreply,
     socket
     |> put_flash(:info, "Video deleted successfully.")
     |> push_navigate(to: ~p"/videos")}
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
