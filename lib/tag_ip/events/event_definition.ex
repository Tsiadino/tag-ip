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
    attribute(:category, :atom, allow_nil?: false)
    attribute(:class, :atom, allow_nil?: false, default: :unknown)
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
    defaults([:read, :create, :update, :destroy])
  end
end
