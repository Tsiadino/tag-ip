alias Ecto.UUID
alias EventDefinition.Repo
alias NimbleCSV.RFC4180, as: CSV

# Create default super-admin user
default_password = "tagip2024"

%{
  id: Ecto.UUID.dump!(UUID.generate()),
  email: "fannie@gmail.com",
  hashed_password: Bcrypt.hash_pwd_salt(default_password)
}
|> then(fn user ->
  Repo.insert_all("users", [user],
    on_conflict: :nothing,
    conflict_target: :email
  )
end)

IO.puts("Default user created: fannie@gmail.com / #{default_password}")

# Create organizations
organizations = [
  %{name: "Demo Corp", slug: "demo_corp"},
  %{name: "Org 1", slug: "org_1"},
  %{name: "Org 2", slug: "org_2"},
  %{name: "Org 3", slug: "org_3"},
  %{name: "Org 4", slug: "org_4"},
  %{name: "Org 5", slug: "org_5"}
]

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

organizations
|> Enum.map(fn org ->
  %{
    id: Ecto.UUID.dump!(UUID.generate()),
    name: org.name,
    slug: org.slug,
    config: %{},
    inserted_at: now,
    updated_at: now
  }
end)
|> Enum.each(fn org ->
  Repo.insert_all("organizations", [org], on_conflict: :nothing, conflict_target: :slug)
end)

csv_path = Path.expand("../../event_descriptions.csv", __DIR__)

unless File.exists?(csv_path) do
  Mix.raise("CSV file not found: #{csv_path}")
end

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

csv_path
|> File.stream!()
|> CSV.parse_stream()
|> Stream.map(fn row ->
  code = Enum.at(row, 1)
  category = Enum.at(row, 2)
  definition = Enum.at(row, 3)
  name = Enum.at(row, 4)
  level = Enum.at(row, 11)
  monitor_type = row |> Enum.filter(&(&1 != "")) |> List.last() || "track.events"

  id_string = UUID.generate()

  %{
    id: Ecto.UUID.dump!(id_string),
    code: code,
    name: name,
    definition: definition,
    category: category,
    class: "unknown",
    level:
      case Integer.parse(to_string(level || "")) do
        {value, _} -> value
        _ -> 1
      end,
    monitor_type: monitor_type,
    active: true,
    inserted_at: now,
    updated_at: now
  }
end)
|> Enum.chunk_every(100)
|> Enum.each(fn chunk ->
  Repo.insert_all("event_definitions", chunk,
    on_conflict: :nothing,
    conflict_target: :code
  )
end)
