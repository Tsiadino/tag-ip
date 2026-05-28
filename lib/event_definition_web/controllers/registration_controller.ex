defmodule EventDefinitionWeb.RegistrationController do
  use EventDefinitionWeb, :controller

  alias EventDefinition.Accounts.Auth

  def new(conn, _params) do
    form = Phoenix.Component.to_form(Auth.change_registration(), as: "user")
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    case Auth.register_user(user_params) do
      {:ok, user} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Votre compte a été créé avec succès.")
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        form = Phoenix.Component.to_form(changeset, as: "user")

        conn
        |> put_flash(:error, "Impossible de créer le compte.")
        |> render(:new, form: form)
    end
  end
end
