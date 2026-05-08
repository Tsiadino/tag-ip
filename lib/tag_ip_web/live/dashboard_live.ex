defmodule TagIpWeb.DashboardLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    events =
      from(e in "event_definitions",
        select: %{
          id: e.id,
          code: e.code,
          name: e.name,
          category: e.category,
          active: e.active
        },
        order_by: e.name
      )
      |> Repo.all()
      |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)
      |> Enum.map(&Map.put(&1, :enabled, &1.active))

    {:ok,
     assign(socket,
       events: events,
       filter: "all",
       alerts: []
     )}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end

  @impl true
  def handle_event("dismiss_alert", %{"id" => id}, socket) do
    alerts = Enum.reject(socket.assigns.alerts, &(to_string(&1.id) == id))
    {:noreply, assign(socket, :alerts, alerts)}
  end

  @impl true
  def handle_event("toggle_event", %{"id" => id}, socket) do
    events =
      Enum.map(socket.assigns.events, fn event ->
        if to_string(event.id) == id do
          %{event | enabled: !event.enabled}
        else
          event
        end
      end)

    {:noreply, assign(socket, events: events)}
  end

  @impl true
  def handle_info({:global_event_toggled, event_id, active}, socket) do
    updated_event =
      Enum.find(socket.assigns.events, fn e -> to_string(e.id) == to_string(event_id) end)

    label = if active, do: "activée", else: "désactivée"

    alert = %{
      id: System.unique_integer([:positive]),
      text: "Définition globale « #{updated_event && updated_event.name} » #{label}",
      type: if(active, do: "success", else: "info"),
      timestamp: DateTime.utc_now()
    }

    events =
      Enum.map(socket.assigns.events, fn event ->
        if to_string(event.id) == to_string(event_id) do
          %{event | active: active, enabled: active}
        else
          event
        end
      end)

    {:noreply,
     socket
     |> assign(:events, events)
     |> assign(:alerts, [alert | socket.assigns.alerts])}
  end

  @impl true
  def handle_info({:global_reset, active}, socket) do
    label = if active, do: "activés", else: "désactivés"
    
    alert = %{
      id: System.unique_integer([:positive]),
      text: "ALERTE SYSTÈME : Tous les événements ont été #{label} via l'initialisation.",
      type: if(active, do: "success", else: "info"),
      timestamp: DateTime.utc_now()
    }

    # On remet à jour tous les événements localement pour que l'UI change aussi
    events = Enum.map(socket.assigns.events, fn event ->
      %{event | active: active, enabled: active}
    end)

    {:noreply,
    socket
    |> assign(:events, events)
    |> assign(:alerts, [alert | socket.assigns.alerts])}
  end

  @impl true
  def render(assigns) do
    filtered_events =
      case assigns.filter do
        "all" -> assigns.events
        "infraction" -> Enum.filter(assigns.events, &(&1.category == "infraction"))
        "information" -> Enum.filter(assigns.events, &(&1.category == "information"))
        _ -> assigns.events
      end

    assigns = assign(assigns, :filtered_events, filtered_events)

    ~H"""
    <section class="space-y-6">
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up">
        <div class="flex items-center gap-4 mb-4">
          <div class="size-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-chart-bar" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Dashboard Temps Réel
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">Vue centralisée de tous les événements système</p>
          </div>
        </div>
      </div>

      <%= if @alerts != [] do %>
        <div class="space-y-2 animate-fade-in-up delay-1" id="alerts">
          <%= for alert <- @alerts do %>
            <div class={[
              "flex items-center justify-between px-4 py-3 rounded-lg border shadow-sm transition-all duration-200",
              alert.type == "success" && "bg-green-50 border-green-200 text-green-800",
              alert.type == "info" && "bg-blue-50 border-blue-200 text-blue-800"
            ]}>
              <div class="flex items-center gap-2 text-sm font-medium">
                <.icon
                  name={
                    if(alert.type == "success",
                      do: "hero-check-circle",
                      else: "hero-information-circle"
                    )
                  }
                  class="size-5 shrink-0"
                />
                <span>{alert.text}</span>
              </div>
              <button
                phx-click="dismiss_alert"
                phx-value-id={alert.id}
                class="shrink-0 p-1 rounded hover:bg-white/50 transition-colors"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 animate-fade-in-up delay-2">
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-blue-600">{Enum.count(@events, & &1.active)}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">
            Événements actifs
          </p>
        </div>
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-blue-600">{Enum.count(@events, & &1.enabled)}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">
            Événements activés
          </p>
        </div>
        <div class="bg-white rounded-lg p-4 text-center border border-gray-200 shadow-sm transition-all duration-200 hover:shadow-md">
          <p class="text-2xl font-extrabold text-gray-900">{length(@events)}</p>
          <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider mt-0.5">
            Total événements
          </p>
        </div>
      </div>

      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up delay-3">
        <h2 class="text-base font-bold text-gray-900 mb-4">Filtres</h2>
        <div class="flex flex-wrap gap-2">
          <button
            phx-click="filter"
            phx-value-filter="all"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200",
              if(@filter == "all",
                do: "bg-blue-600 text-white shadow-sm",
                else:
                  "bg-white text-gray-600 border border-gray-300 hover:border-blue-400 hover:text-blue-600"
              )
            ]}
          >
            Tous ({length(@events)})
          </button>
          <button
            phx-click="filter"
            phx-value-filter="infraction"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200",
              if(@filter == "infraction",
                do: "bg-blue-600 text-white shadow-sm",
                else:
                  "bg-white text-gray-600 border border-gray-300 hover:border-blue-400 hover:text-blue-600"
              )
            ]}
          >
            Infractions ({Enum.count(@events, &(&1.category == "infraction"))})
          </button>
          <button
            phx-click="filter"
            phx-value-filter="information"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200",
              if(@filter == "information",
                do: "bg-blue-600 text-white shadow-sm",
                else:
                  "bg-white text-gray-600 border border-gray-300 hover:border-blue-400 hover:text-blue-600"
              )
            ]}
          >
            Information ({Enum.count(@events, &(&1.category == "information"))})
          </button>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-4">
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900">Événements</h2>
          <span class="px-2.5 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-600">
            {length(@filtered_events)} résultat(s)
          </span>
        </div>
        <div class="p-6 grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          <%= for event <- @filtered_events do %>
            <div class="bg-white rounded-lg p-4 border border-gray-200 shadow-sm hover:shadow-md transition-all duration-200 hover:-translate-y-0.5">
              <div class="flex items-start justify-between mb-3">
                <span class={[
                  "px-2.5 py-0.5 text-xs font-semibold rounded",
                  event.category == "infraction" && "bg-gray-800 text-white",
                  event.category == "information" && "bg-gray-100 text-gray-700"
                ]}>
                  {event.category}
                </span>
                <button
                  phx-click="toggle_event"
                  phx-value-id={event.id}
                  class={[
                    "px-3 py-1 text-xs font-semibold rounded-lg transition-all duration-200",
                    if(event.enabled,
                      do: "bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-300",
                      else: "bg-blue-600 text-white hover:bg-blue-700 shadow-sm"
                    )
                  ]}
                >
                  {if event.enabled, do: "Désactiver", else: "Activer"}
                </button>
              </div>
              <h3 class="text-sm font-bold text-gray-900 mb-1 leading-snug">{event.name}</h3>
              <p class="text-xs font-mono text-gray-400 mb-3">{event.code}</p>
              <div class="flex items-center gap-2 pt-3 border-t border-gray-50">
                <span class={[
                  "size-2 rounded-full",
                  if(event.enabled, do: "bg-blue-600", else: "bg-gray-300")
                ]} />
                <span class={[
                  "text-xs font-semibold",
                  if(event.enabled, do: "text-blue-600", else: "text-gray-400")
                ]}>
                  {if event.enabled, do: "Activé", else: "Désactivé"}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-4 pt-2 animate-fade-in-up delay-5">
        <.link
          navigate="/"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-600 hover:text-blue-600 bg-white hover:bg-blue-50 rounded-lg border border-gray-300 hover:border-blue-400 transition-all duration-200"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Retour à l'accueil
        </.link>
        <.link
          navigate="/init"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-sm transition-all duration-200"
        >
          Initialisation <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </div>
    </section>
    """
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
