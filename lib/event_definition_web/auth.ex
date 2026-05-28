defmodule EventDefinitionWeb.Auth do
  @moduledoc """
  Authentication hooks for LiveViews.
  """
  use EventDefinitionWeb, :verified_routes

  def on_mount(:ensure_authenticated, _params, session, socket) do
    current_user =
      socket.assigns[:current_user] ||
        (session["user_id"] && EventDefinition.Accounts.Auth.get_user(session["user_id"]))

    if current_user do
      {:cont, Phoenix.Component.assign(socket, :current_user, current_user)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/login")}
    end
  end
end
