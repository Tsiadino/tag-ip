defmodule EventDefinition.Repo.Migrations.CreateAlertLogs do
  @moduledoc """
  Migration nettoyée manuellement pour ne créer que la table alert_logs.
  """

  use Ecto.Migration

  def up do
    # ON NE GARDE QUE ÇA :
    create table(:alert_logs, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :event, :text, null: false
      add :status, :text, null: false, default: "sent"
      add :timestamp, :utc_datetime, null: false, default: fragment("(now() AT TIME ZONE 'utc')")

      add :organization_id,
          references(:organizations,
            column: :id,
            name: "alert_logs_organization_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end
  end

  def down do
    drop constraint(:alert_logs, "alert_logs_organization_id_fkey")
    drop table(:alert_logs)
  end
end
