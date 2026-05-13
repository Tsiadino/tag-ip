defmodule TagIpWeb.PasswordResetController do
  use TagIpWeb, :controller

  def new(conn, _params) do
    render(conn, :new)
  end
end
