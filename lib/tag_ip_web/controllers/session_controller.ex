defmodule TagIpWeb.SessionController do
  use TagIpWeb, :controller

  alias TagIp.Accounts.Auth

  def new(conn, _params) do
    email = get_session(conn, :email) || ""
    form = Phoenix.Component.to_form(%{"email" => email}, as: "session")
    render(conn, :new, form: form)
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case Auth.authenticate(email, password) do
      {:ok, user} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> delete_session(:email)
        |> put_flash(:info, "Connexion réussie. Bienvenue sur Tag-IP.")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        form = Phoenix.Component.to_form(%{"email" => email}, as: "session")

        conn
        |> put_flash(:error, "Email ou mot de passe incorrect.")
        |> put_session(:email, email)
        |> render(:new, form: form)
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Veuillez remplir tous les champs.")
    |> redirect(to: ~p"/login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Vous êtes maintenant déconnecté.")
    |> redirect(to: ~p"/login")
  end
end
