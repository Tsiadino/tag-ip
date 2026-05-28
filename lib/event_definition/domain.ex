defmodule EventDefinition.Domain do
  use Ash.Domain,
    otp_app: :event_definition,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(EventDefinition.Accounts.Organization)
    resource(EventDefinition.Events.EventDefinition)
    resource(EventDefinition.Events.OrganizationEventDefinition)
    resource(EventDefinition.Events.AlertLog)
    resource(EventDefinition.Events.AuditLog)
  end
end
