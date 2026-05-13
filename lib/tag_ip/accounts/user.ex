defmodule TagIp.Accounts.User do
  use Ash.Resource,
    domain: TagIp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, allow_nil?: true, sensitive?: true)
  end

  authentication do
    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
      end
    end

    tokens do
      enabled?(true)
      token_resource(TagIp.Accounts.Token)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        {:ok, Application.fetch_env!(:tag_ip, TagIpWeb.Endpoint)[:secret_key_base]}
      end)
    end
  end

  postgres do
    table("users")
    repo(TagIp.Repo)
  end

  identities do
    identity(:unique_email, [:email])
  end

  # Dans ton ressource User
  actions do
    defaults([:read, :create, :update, :destroy])

    read :by_email do
      argument(:email, :string, allow_nil?: false)
      get?(true)
      filter(expr(email == ^arg(:email)))
    end
  end
end
