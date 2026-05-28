defmodule EventDefinitionWeb.PageController do
  use EventDefinitionWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
