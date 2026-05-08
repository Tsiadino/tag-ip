defmodule TagIpWeb.InitLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 1, from: 2]

  @impl true
  def mount(_params, _session, socket) do
    # On charge toutes les données (événements + organisations) dès le début
    {:ok, refresh_all_data(socket)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  # Handler pour ajouter une organisation avec persistance DB
  @impl true
  def handle_event("add_org", _params, socket) do
    # 1. On calcule le numéro de la nouvelle organisation
    count = Repo.aggregate(from(o in "organizations"), :count, :id)
    new_id = count + 1
    name = "Organization #{new_id}"
    slug = "org_#{new_id}"
    
    # 2. Insertion réelle dans la table SQL
    # Note : On ajoute les timestamps car Ecto en a besoin pour la table qu'on a créée
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    Repo.insert_all("organizations", [[
      name: name, 
      slug: slug, 
      inserted_at: now, 
      updated_at: now
    ]])
    
    {:noreply, 
     socket 
     |> put_flash(:info, "#{name} a été créée avec succès !")
     |> refresh_all_data()}
  end

  @impl true
  def handle_event("activate_all", _params, socket) do
    from(e in "event_definitions") |> Repo.update_all(set: [active: true])

    Phoenix.PubSub.broadcast(
      TagIp.PubSub,
      "global_events",
      {:global_reset, true}
    )

    {:noreply, 
     socket 
     |> put_flash(:info, "Tous les événements ont été activés")
     |> refresh_all_data()}
  end

  @impl true
  def handle_event("deactivate_all", _params, socket) do
    from(e in "event_definitions") |> Repo.update_all(set: [active: false])

    Phoenix.PubSub.broadcast(
      TagIp.PubSub,
      "global_events",
      {:global_reset, false}
    )

    {:noreply, 
     socket 
     |> put_flash(:info, "Tous les événements ont été désactivés")
     |> refresh_all_data()}
  end

  # Fonction unique pour rafraîchir tout l'état du socket
  defp refresh_all_data(socket) do
    total = Repo.aggregate(from(e in "event_definitions"), :count, :id)
    active = Repo.aggregate(from(e in "event_definitions", where: e.active == true), :count, :id)
    
    # On récupère les noms de toutes les organisations en DB
    orgs = Repo.all(from(o in "organizations", select: o.name, order_by: [asc: o.id]))
    
    assign(socket,
      total_events: total,
      active_events: active,
      organizations: orgs
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <%!-- Ton code de rendu reste identique ici, 
           il utilisera automatiquement les données de la DB --%>
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up">
        <div class="flex items-center gap-4 mb-4">
          <div class="size-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-rocket-launch" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Initialisation et Provisioning
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">
              Configurez le système PiEvents pour vos organisations
            </p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 animate-fade-in-up delay-1">
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-blue-600">{@total_events}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">Événements importés</p>
        </div>
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-blue-600">{@active_events}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">Événements actifs</p>
        </div>
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-gray-900">{length(@organizations)}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">Organisations</p>
        </div>
      </div>

      <%!-- Section Actions Globales --%>
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up delay-2">
        <h2 class="text-base font-bold text-gray-900 mb-4">Actions globales</h2>
        <div class="flex flex-wrap gap-3">
          <button phx-click="activate_all" class="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-all duration-200 text-sm shadow-sm">
            <.icon name="hero-check-circle" class="size-4" /> Activer tous les événements
          </button>
          <button phx-click="deactivate_all" class="inline-flex items-center gap-2 px-5 py-2.5 bg-gray-200 hover:bg-gray-300 text-gray-700 font-semibold rounded-lg transition-all duration-200 text-sm">
            <.icon name="hero-x-circle" class="size-4" /> Désactiver tous les événements
          </button>
        </div>
      </div>

      <%!-- Section Liste des Organisations --%>
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-3">
        <div class="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
          <h2 class="text-base font-bold text-gray-900">Organisations configurées</h2>
          <button 
            phx-click="add_org"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 text-blue-700 hover:bg-blue-100 font-bold rounded-lg transition-all text-xs border border-blue-200"
          >
            <.icon name="hero-plus-circle" class="size-4" /> Ajouter une organisation
          </button>
        </div>

        <div class="p-6 grid gap-2">
          <%= for org <- @organizations do %>
            <div class="flex items-center justify-between px-4 py-3 bg-gray-50 rounded-lg border border-gray-200 hover:bg-blue-50 hover:border-blue-200 transition-all duration-200">
              <span class="text-sm font-semibold text-gray-700">{org}</span>
              <span class="inline-flex items-center gap-1 px-2.5 py-0.5 text-xs font-semibold rounded-full bg-gray-100 text-gray-600 border border-gray-200">
                <.icon name="hero-check" class="size-3" /> Configurée
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Footer Navigation --%>
      <div class="flex flex-wrap items-center justify-between gap-4 pt-2 animate-fade-in-up delay-5">
        <.link navigate="/dashboard" class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-600 hover:text-blue-600 bg-white hover:bg-blue-50 rounded-lg border border-gray-300 hover:border-blue-400 transition-all duration-200">
          <.icon name="hero-arrow-left" class="size-4" /> Dashboard
        </.link>
        <.link navigate="/monitoring" class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-sm transition-all duration-200">
          Monitoring <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </div>
    </section>
    """
  end
end