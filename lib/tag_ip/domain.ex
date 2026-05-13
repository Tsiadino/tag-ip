defmodule TagIp.Domain do
  use Ash.Domain

  resources do
    resource(TagIp.Accounts.Organization)
    resource(TagIp.Events.EventDefinition)
    resource(TagIp.Events.OrganizationEventDefinition)
    resource(TagIp.Events.AlertLog)
    resource(TagIp.Events.AuditLog)
  end
end
