defmodule TagIpWeb.OrgEventsLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  # On importe seulement ce qui est nécessaire pour éviter les warnings inutilisés
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    # On récupère les événements (Requête Ecto conservée pour la précision du select/limit)
    events =
      from(e in "event_definitions",
        select: %{
          id: e.id,
          code: e.code,
          name: e.name,
          monitor_type: e.monitor_type,
          active: e.active
        },
        order_by: e.code,
        limit: 8
      )
      |> Repo.all()
      |> Enum.map(fn event -> 
        event 
        |> Map.put(:id, normalize_uuid(event.id))
        |> Map.put(:enabled, event.active) 
      end)

    # Chargement des organisations
    organizations_list = Repo.all(from(o in "organizations", select: o.name, order_by: [asc: o.id]))

    {:ok,
      assign(socket,
        events: events,
        organizations_list: organizations_list,
        organization: List.first(organizations_list) || "Aucune organisation"
      )}
  end

  # --- SYNCHRONISATION TEMPS RÉEL ---
  @impl true
  def handle_info({:org_created, _new_name}, socket) do
    new_list = Repo.all(from(o in "organizations", select: o.name, order_by: [asc: o.id]))
    {:noreply, assign(socket, organizations_list: new_list)}
  end

  @impl true
  def handle_info({:global_reset, status}, socket) do
    updated_events = Enum.map(socket.assigns.events, & %{&1 | enabled: status, active: status})
    {:noreply, assign(socket, events: updated_events)}
  end
  
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  # --- GESTION DES ÉVÉNEMENTS UI ---
  @impl true
  def handle_event("toggle-enabled", %{"id" => id}, socket) do
    binary_id = Ecto.UUID.cast!(id)
    events = socket.assigns.events
    target_event = Enum.find(events, fn e -> to_string(e.id) == to_string(id) end)
    new_status = !target_event.enabled

    # Mise à jour DB
    from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
    |> Repo.update_all(set: [active: new_status])

    Phoenix.PubSub.broadcast(TagIp.PubSub, "global_events", {:global_event_toggled, id, new_status})

    updated_events = Enum.map(events, fn event ->
      if to_string(event.id) == to_string(id), do: %{event | enabled: new_status, active: new_status}, else: event
    end)

    {:noreply, assign(socket, events: updated_events)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up">
        <div class="flex items-center gap-4 mb-4">
          <div class="size-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-building-office-2" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Configuration par organisation
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">Activez les événements par organisation</p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl p-5 shadow-sm border border-gray-200 animate-fade-in-up delay-1">
          <h2 class="text-sm font-bold text-gray-900 mb-3">Organisation</h2>
          <p class="text-xs text-gray-400 mb-2">Total : {length(@organizations_list)}</p>
          <div class="relative">
            <select class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all outline-none text-sm font-medium text-gray-700 appearance-none cursor-pointer">
              <option selected>{@organization}</option>
              <%= for org_name <- @organizations_list do %>
                <%= if org_name != @organization do %>
                  <option value={org_name}>{org_name}</option>
                <% end %>
              <% end %>
            </select>
            <.icon name="hero-chevron-down" class="size-4 absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
          </div>
        </div>

        <div class="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-2">
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <h2 class="text-sm font-bold text-gray-900">Événements disponibles</h2>
            <span class="px-2.5 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-600">
              {length(@events)}
            </span>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-gray-50 border-b border-gray-200">
                  <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Événement</th>
                  <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Visible</th>
                  <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Action</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <%= for event <- @events do %>
                  <tr class="hover:bg-gray-50 transition-colors duration-150">
                    <td class="px-5 py-3.5">
                      <span class="text-gray-800 font-medium">{event.name}</span>
                      <span class="text-gray-400 font-mono text-xs ml-1.5">({event.code})</span>
                    </td>
                    <td class="px-5 py-3.5">
                      <span class={[
                        "inline-flex items-center gap-1.5 px-2.5 py-0.5 text-xs font-semibold rounded-full",
                        if(event.enabled, do: "text-blue-600 bg-blue-50 border border-blue-200", else: "text-gray-500 bg-gray-50 border border-gray-200")
                      ]}>
                        <span class={["size-1.5 rounded-full", if(event.enabled, do: "bg-blue-600", else: "bg-gray-400")]} />
                        {if event.enabled, do: "Oui", else: "Non"}
                      </span>
                    </td>
                    <td class="px-5 py-3.5">
                      <button phx-click="toggle-enabled" phx-value-id={event.id} class={[
                        "px-3.5 py-1.5 text-xs font-bold rounded-lg transition-all duration-200",
                        if(event.enabled, do: "bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-300", else: "bg-blue-600 text-white hover:bg-blue-700 shadow-sm")
                      ]}>
                        {if event.enabled, do: "Désactiver", else: "Activer"}
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
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