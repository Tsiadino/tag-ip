defmodule EventDefinition.Accounts do
  use Ash.Domain,
    otp_app: :event_definition,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(EventDefinition.Accounts.User)
    resource(EventDefinition.Accounts.Token)
  end
end
