defmodule TagIp.Accounts.Token do
  use Ash.Resource,
    domain: TagIp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(TagIp.Repo)
  end
end
