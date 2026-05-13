defmodule TagIp.Accounts do
  use Ash.Domain

  resources do
    resource(TagIp.Accounts.User)
    # Vérifie que cette ligne est bien là !
    resource(TagIp.Accounts.Token)
  end
end
