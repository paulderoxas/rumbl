defmodule RumblWeb.VideoLive.New do
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
      changeset = Multimedia.change_video(%Video{})
      categories = Multimedia.category_options()

      {:ok,
       assign(socket,
         changeset: changeset,
         categories: categories,
         current_user: current_user
       )}
    end
  end

  # Live validation on every keystroke (phx-change="validate")
  def handle_event("validate", %{"video" => video_params}, socket) do
    changeset =
      %Video{}
      |> Multimedia.change_video(video_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  # Form submission (phx-submit="save")
  def handle_event("save", %{"video" => video_params}, socket) do
    case Multimedia.create_video(socket.assigns.current_user, video_params) do
      {:ok, video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Video created successfully.")
         |> push_navigate(to: ~p"/videos/#{video.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
