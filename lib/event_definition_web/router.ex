defmodule EventDefinitionWeb.Router do
  use EventDefinitionWeb, :router

  # Réimport de la macro officielle d'AshAdmin
  import AshAdmin.Router

  # 1. PIPELINES
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EventDefinitionWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
  end

  # Nouveau pipeline dédié à la sécurité de l'administration
  pipeline :super_admin_only do
    plug :ensure_super_admin
  end

  pipeline :auth_layout do
    plug :put_root_layout, html: {EventDefinitionWeb.Layouts, :auth_root}
  end

  # 2. LES BLOCS DE ROUTES

  # Interface d'administration AshAdmin entièrement protégée
  scope "/" do
    pipe_through [:browser, :super_admin_only]

    # Plus besoin de lui passer la liste ici, il va la lire dans config.exs
    ash_admin("/admin")
  end

  # Routes d'authentification
  scope "/", EventDefinitionWeb do
    pipe_through [:browser, :auth_layout]

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create

    get "/reset-password", PasswordResetController, :new
  end

  # --- ROUTES PROTÉGÉES POUR UTILISATEURS LAMBDA ---
  scope "/", EventDefinitionWeb do
    pipe_through [:browser]

    live_session :authenticated, on_mount: [{EventDefinitionWeb.Auth, :ensure_authenticated}] do
      live "/", HomeLive, :index
      live "/dashboard", DashboardLive, :index
      live "/init", InitLive, :index
      live "/global-events", GlobalEventsLive, :index
      live "/global-events/new", EventNewLive, :new
      live "/global-events/:id/edit", EventEditLive, :edit
      live "/org-events", OrgEventsLive, :index
      live "/org-events/:id/config", OrgEventConfigLive, :config
      live "/monitoring", MonitoringLive, :index
    end
  end

  # 3. ALIAS ET FONCTIONS PRIVÉES
  # Permet d'appeler directement le module sans écrire tout le chemin
  defp ensure_super_admin(conn, opts),
    do: EventDefinitionWeb.Plugs.EnsureSuperAdmin.call(conn, opts)

  defp load_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    assign(
      conn,
      :current_user,
      if(user_id, do: EventDefinition.Accounts.Auth.get_user(user_id), else: nil)
    )
  end
end
