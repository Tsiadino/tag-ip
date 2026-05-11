defmodule TagIp.Events.AuditLog do
  use Ash.Resource,
    domain: TagIp.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(TagIp.Repo)
    table("audit_logs")
  end

  attributes do
    uuid_primary_key(:id)
    attribute :user, :string, allow_nil?: false
    attribute :action, :string, allow_nil?: false
    attribute :event, :string, allow_nil?: false
    
    # On utilise timestamps() pour avoir inserted_at automatiquement
    timestamps()
  end

  actions do
    defaults [:read]

    create :create do
        # Ajoute cette ligne pour autoriser l'écriture de ces champs
        accept [:user, :action, :event]
    end
  end
end