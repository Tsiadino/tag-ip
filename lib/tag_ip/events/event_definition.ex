defmodule TagIp.Events.EventDefinition do
  use Ash.Resource,
    domain: TagIp.Domain,
    extensions: [AshAdmin.Resource, AshPhoenix.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(TagIp.Repo)
    table("event_definitions")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:code, :string, allow_nil?: false)
    attribute(:name, :string, allow_nil?: false)
    attribute(:definition, :string)

    # On définit l'attribut une seule fois avec toutes ses contraintes
    attribute :category, :atom do
      allow_nil?(false)
      constraints(unsafe_to_atom?: true)
    end

    # Il est prudent de faire pareil pour :class si tes données CSV sont variées
    attribute :class, :atom do
      allow_nil?(false)
      default(:unknown)
      constraints(unsafe_to_atom?: true)
    end

    attribute(:level, :integer, allow_nil?: false, constraints: [min: 1])
    attribute(:level_group, :string)
    attribute(:monitor_type, :string, allow_nil?: false)
    attribute(:active, :boolean, default: true)
    timestamps()
  end

  relationships do
    has_many :organization_event_definitions, TagIp.Events.OrganizationEventDefinition,
      destination_attribute: :event_definition_id
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :monitor_type,
        :active
      ])
    end

    update :update do
      primary?(true)

      accept([
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :monitor_type,
        :active
      ])
    end
  end
end
