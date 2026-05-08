defmodule TagIp.Accounts.Organization do
  use Ash.Resource,
    domain: TagIp.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("organizations")
    repo(TagIp.Repo)
  end

  actions do
    defaults([:read, :create, :update])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^[a-z0-9_-]+$/)
    end

    attribute :config, :map do
      allow_nil?(true)
      public?(true)
      default(%{})
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  def by_slug!(slug) do
    TagIp.Accounts.Organization
    |> Ash.read!(filter: [slug: slug])
    |> List.first()
  end
end
