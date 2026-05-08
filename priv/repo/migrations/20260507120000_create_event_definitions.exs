defmodule TagIp.Repo.Migrations.CreateEventDefinitions do
  use Ecto.Migration

  def change do
    create table(:event_definitions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :definition, :text
      add :category, :string, null: false
      add :class, :string, null: false, default: "unknown"
      add :level, :integer, null: false
      add :level_group, :string
      add :monitor_type, :string, null: false
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_definitions, [:code])
  end
end
