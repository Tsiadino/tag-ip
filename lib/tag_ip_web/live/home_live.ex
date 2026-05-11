defmodule TagIpWeb.HomeLive do
  use TagIpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # 1. S'abonner au canal "global_events" pour le temps réel
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    # 2. Charger les comptes via ASH (plus besoin de Repo ou d'Ecto.Query)
    # On utilise count!() qui est fourni nativement par Ash
    event_count = TagIp.Events.EventDefinition |> Ash.count!()
    org_count = TagIp.Accounts.Organization |> Ash.count!()

    {:ok,
     assign(socket,
       event_count: event_count,
       org_count: org_count
     )}
  end

  # --- SYNCHRONISATION TEMPS RÉEL ---
  
  @impl true
  def handle_info({:org_created, _name}, socket) do
    # On incrémente le compteur actuel dans le socket sans recharger la DB
    new_count = socket.assigns.org_count + 1
    {:noreply, assign(socket, org_count: new_count)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="bg-white rounded-xl p-6 md:p-8 shadow-sm border border-gray-200 animate-fade-in-up">
        <div class="flex items-center gap-4 mb-5">
          <div class="size-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-cpu-chip" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Gestion des événements
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">Interface de démonstration Phoenix + Ash</p>
          </div>
        </div>
        <p class="text-gray-600 leading-relaxed">
          Gérez le catalogue global des événements et les configurations d'organisation.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 animate-fade-in-up delay-1">
          <div class="size-10 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm mb-4">
            <.icon name="hero-globe-alt" class="size-5 text-white" />
          </div>
          <h2 class="text-lg font-bold text-gray-900 mb-2">Catalogue global</h2>
          <p class="text-sm text-gray-500 leading-relaxed mb-5">
            Suivez le nombre total de définitions globales importées depuis le CSV.
          </p>
          <div class="bg-gray-50 rounded-lg p-4 text-center border border-gray-200 mb-5">
            <p class="text-3xl font-extrabold text-blue-600">{@event_count}</p>
            <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">
              Événements globaux
            </p>
          </div>
          <.link
            navigate="/global-events"
            class="inline-flex items-center justify-center gap-2 w-full px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-all duration-200 text-sm shadow-sm"
          >
            Voir les définitions globales <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>

        <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 animate-fade-in-up delay-2">
          <div class="size-10 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm mb-4">
            <.icon name="hero-building-office" class="size-5 text-white" />
          </div>
          <h2 class="text-lg font-bold text-gray-900 mb-2">Configurations par organisation</h2>
          <p class="text-sm text-gray-500 leading-relaxed mb-5">
            Activez et personnalisez les événements par organisation.
          </p>
          <div class="bg-gray-50 rounded-lg p-4 text-center border border-gray-200 mb-5">
            <p class="text-3xl font-extrabold text-gray-900">{@org_count}</p>
            <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">
              Organisations
            </p>
          </div>
          <.link
            navigate="/org-events"
            class="inline-flex items-center justify-center gap-2 w-full px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-all duration-200 text-sm shadow-sm"
          >
            Voir les configurations <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>
      </div>
    </section>
    """
  end
end