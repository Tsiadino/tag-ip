defmodule TagIpWeb.PageController do
  use TagIpWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
