defmodule EventDefinitionWeb.PasswordResetController do
  use EventDefinitionWeb, :controller

  def new(conn, _params) do
    render(conn, :new)
  end
end
