defmodule TagIp.Repo do
  use Ecto.Repo,
    otp_app: :tag_ip,
    adapter: Ecto.Adapters.Postgres
end
