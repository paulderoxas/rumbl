defmodule Rumbl.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :code, :string, null: false
      add :is_active, :boolean, default: true, null: false
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :host_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:rooms, [:code])
    create index(:rooms, [:video_id])
    create index(:rooms, [:host_id])
  end
end
