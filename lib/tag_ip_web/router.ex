defmodule TagIpWeb.Router do
  use TagIpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TagIpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
  end

  pipeline :auth_layout do
    plug :put_root_layout, html: {TagIpWeb.Layouts, :auth_root}
  end

  scope "/", TagIpWeb do
    pipe_through [:browser, :auth_layout]

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create

    get "/reset-password", PasswordResetController, :new
  end

  # --- ROUTES PROTÉGÉES ---
  scope "/", TagIpWeb do
    pipe_through [:browser]

    live_session :authenticated, on_mount: [{TagIpWeb.Auth, :ensure_authenticated}] do
      live "/", HomeLive, :index
      live "/dashboard", DashboardLive, :index
      live "/init", InitLive, :index
      live "/global-events", GlobalEventsLive, :index
      live "/org-events", OrgEventsLive, :index
      live "/monitoring", MonitoringLive, :index
    end
  end

  defp load_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    assign(conn, :current_user, if(user_id, do: TagIp.Accounts.Auth.get_user(user_id), else: nil))
  end
end
