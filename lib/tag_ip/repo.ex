defmodule TagIp.Repo do
  use AshPostgres.Repo,
    otp_app: :tag_ip

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions"] # Ajout de ash-functions
  end

  # Ajoute ceci pour préciser la version de ton Postgres sur Debian
  def min_pg_version do
    %Version{major: 15, minor: 0, patch: 0}
  end
end