defmodule TagIp.Events.AlertLog do
  use Ash.Resource,
    # On reste dans le même domaine que tes autres ressources
    domain: TagIp.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("alert_logs")
    repo(TagIp.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # On stocke l'événement (ex: "Vitesse > 90 km/h")
    attribute :event, :string do
      allow_nil?(false)
      public?(true)
    end

    # Statut de l'envoi (Envoyé, En attente)
    attribute :status, :string do
      allow_nil?(false)
      default("sent")
      public?(true)
    end

    # Horodatage précis de l'alerte
    attribute :timestamp, :utc_datetime do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
      public?(true)
    end

    # ID de l'organisation pour la liaison SQL
    attribute :organization_id, :uuid do
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    # On lie l'alerte à une organisation existante
    belongs_to :organization, TagIp.Accounts.Organization do
      source_attribute(:organization_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    # Action utilisée par ton Webhook pour insérer une alerte
    create :create do
      accept([:event, :status, :timestamp, :organization_id])
    end
  end
end
