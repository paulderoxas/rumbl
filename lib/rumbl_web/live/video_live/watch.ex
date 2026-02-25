defmodule RumblWeb.VideoLive.Watch do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video

  def mount(%{"id" => id}, session, socket) do
    current_user = get_user_from_session(session)
    video = Multimedia.get_video!(id)
    annotations = Multimedia.list_annotations(video)

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
       user_token: user_token
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

  defp get_user_from_session(session) do
    with user_id when not is_nil(user_id) <- Map.get(session, "user_id") do
      Rumbl.Accounts.get_user(user_id)
    end
  end
end
