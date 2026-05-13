defmodule TagIpWeb.AuthController do
  use TagIpWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, _user, _token) do
    conn
    |> put_flash(:info, "Connexion réussie. Bienvenue sur Tag-IP.")
    # On utilise le redirect standard de Phoenix vers la racine (HomeLive)
    |> redirect(to: ~p"/")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Identifiants incorrects ou compte inexistant.")
    |> redirect(to: ~p"/login")
  end

  def sign_out(conn, _user) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Déconnexion réussie.")
    |> redirect(to: ~p"/login")
  end
end
