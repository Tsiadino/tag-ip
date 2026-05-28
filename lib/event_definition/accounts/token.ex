defmodule EventDefinition.Accounts.Token do
  use Ash.Resource,
    domain: EventDefinition.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(EventDefinition.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
