defmodule Rumbl.Multimedia.Room do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.Video

  schema "rooms" do
    field :code, :string
    field :is_active, :boolean, default: true

    belongs_to :video, Video
    belongs_to :host, User

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:code, :is_active, :video_id, :host_id])
    |> validate_required([:code, :video_id, :host_id])
    |> unique_constraint(:code)
  end
end
