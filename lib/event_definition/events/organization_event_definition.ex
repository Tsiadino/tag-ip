defmodule EventDefinition.Events.OrganizationEventDefinition do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    extensions: [AshAdmin.Resource, AshPhoenix.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("organization_event_definitions")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:event_definition_id, :uuid, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:definition, :string, public?: true)
    attribute(:category, :atom, public?: true)
    attribute(:class, :atom, public?: true)
    attribute(:level, :integer, constraints: [min: 1], public?: true)
    attribute(:level_group, :string, public?: true)
    attribute(:occurrence_rule, :map, public?: true)

    attribute(:alert_mode, :atom,
      default: :none,
      constraints: [one_of: [:none, :alert, :report, :both]],
      public?: true
    )

    attribute(:enabled, :boolean, default: true, public?: true)
    attribute(:author_id, :uuid, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :organization, EventDefinition.Accounts.Organization,
      source_attribute: :organization_id,
      destination_attribute: :id

    belongs_to :event_definition, EventDefinition.Events.EventDefinition,
      source_attribute: :event_definition_id
  end

  actions do
    defaults([:read, :create, :update, :destroy])
  end
end
