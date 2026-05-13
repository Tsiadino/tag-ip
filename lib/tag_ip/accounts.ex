defmodule TagIp.Accounts do
  use Ash.Domain

  resources do
    resource TagIp.Accounts.User
    resource TagIp.Accounts.Token # Vérifie que cette ligne est bien là !
  end
end