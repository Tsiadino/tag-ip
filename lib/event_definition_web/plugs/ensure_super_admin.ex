defmodule EventDefinitionWeb.Plugs.EnsureSuperAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    # On récupère l'utilisateur déjà chargé par load_current_user
    current_user = conn.assigns[:current_user]

    # SÉCURITÉ : Accès uniquement pour fannie@gmail.com
    if current_user && current_user.email == "fannie@gmail.com" do
      conn
    else
      conn
      |> put_flash(:error, "Accès réservé aux super-administrateurs.")
      |> redirect(to: "/dashboard")
      # On arrête le traitement de la requête ici
      |> halt()
    end
  end
end
