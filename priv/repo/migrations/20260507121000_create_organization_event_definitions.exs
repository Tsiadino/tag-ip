defmodule TagIp.Repo.Migrations.CreateOrganizationEventDefinitions do
  use Ecto.Migration

  def change do
    create table(:organization_event_definitions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_id, :uuid, null: false

      add :event_definition_id,
          references(:event_definitions, type: :uuid, on_delete: :nilify_all)

      add :code, :string, null: false
      add :name, :string
      add :definition, :text
      add :category, :string
      add :class, :string
      add :level, :integer
      add :level_group, :string
      add :occurrence_rule, :map
      add :alert_mode, :string, null: false, default: "none"
      add :enabled, :boolean, null: false, default: true
      add :author_id, :uuid, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organization_event_definitions, [:organization_id, :event_definition_id],
             name: :org_event_definitions_org_event_definition_index
           )

    create unique_index(:organization_event_definitions, [:organization_id, :code],
             name: :org_event_definitions_org_code_index
           )
  end
end
