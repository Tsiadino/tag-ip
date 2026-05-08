defmodule TagIpWeb.GlobalEventsLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")
    end

    events =
      from(e in "event_definitions",
        select: %{
          id: e.id,
          code: e.code,
          name: e.name,
          definition: e.definition,
          monitor_type: e.monitor_type,
          active: e.active
        },
        order_by: e.code,
        limit: 20
      )
      |> Repo.all()
      |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)

    {:ok, assign(socket, events: events)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  @impl true
  def handle_event("toggle-active", %{"id" => id}, socket) do
    # 1. Convertir l'ID string en UUID binaire pour la base de données
    binary_id = Ecto.UUID.cast!(id)

    # 2. Récupérer l'état actuel pour basculer
    events = socket.assigns.events
    target_event = Enum.find(events, fn e -> to_string(e.id) == to_string(id) end)
    new_status = !target_event.active

    # 3. MISE À JOUR EN BASE DE DONNÉES
    # On utilise type/2 pour dire explicitement à Ecto que c'est un UUID
    from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
    |> Repo.update_all(set: [active: new_status])

    # 4. Broadcast pour le Dashboard
    Phoenix.PubSub.broadcast(
      TagIp.PubSub, 
      "global_events", 
      {:global_event_toggled, id, new_status}
    )

    # 5. Mise à jour de l'interface locale
    updated_events = Enum.map(events, fn event ->
      if to_string(event.id) == to_string(id) do
        %{event | active: new_status}
      else
        event
      end
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
            <.icon name="hero-book-open" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Catalogue global des événements
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">Activez ou désactivez des définitions globales</p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-1">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-200">
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Code
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Nom
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider hidden md:table-cell">
                  Description
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                  Moniteur
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Actif
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Action
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for event <- @events do %>
                <tr class="hover:bg-gray-50 transition-colors duration-150">
                  <td class="px-5 py-3.5 text-gray-900 font-mono text-xs font-semibold">
                    {event.code}
                  </td>
                  <td class="px-5 py-3.5 text-gray-800 font-medium">{event.name}</td>
                  <td class="px-5 py-3.5 text-gray-500 hidden md:table-cell max-w-xs truncate">
                    {event.definition || "—"}
                  </td>
                  <td class="px-5 py-3.5 text-gray-500 hidden sm:table-cell">
                    <span class="px-2 py-0.5 text-xs font-medium rounded bg-gray-100 text-gray-600">
                      {event.monitor_type}
                    </span>
                  </td>
                  <td class="px-5 py-3.5">
                    <span class={[
                      "inline-flex items-center gap-1.5 px-2.5 py-0.5 text-xs font-semibold rounded-full",
                      if(event.active,
                        do: "text-blue-600 bg-blue-50 border border-blue-200",
                        else: "text-gray-500 bg-gray-50 border border-gray-200"
                      )
                    ]}>
                      <span class={[
                        "size-1.5 rounded-full",
                        if(event.active, do: "bg-blue-600", else: "bg-gray-400")
                      ]} />
                      {if event.active, do: "Oui", else: "Non"}
                    </span>
                  </td>
                  <td class="px-5 py-3.5">
                    <button
                      phx-click="toggle-active"
                      phx-value-id={event.id}
                      class={[
                        "px-3.5 py-1.5 text-xs font-bold rounded-lg transition-all duration-200",
                        if(event.active,
                          do: "bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-300",
                          else: "bg-blue-600 text-white hover:bg-blue-700 shadow-sm"
                        )
                      ]}
                    >
                      {if event.active, do: "Désactiver", else: "Activer"}
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up delay-2">
        <div class="flex items-start gap-4">
          <div class="size-10 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-cog-6-tooth" class="size-5 text-white" />
          </div>
          <div>
            <h2 class="text-base font-bold text-gray-900 mb-1">Configurer le catalogue global</h2>
            <p class="text-sm text-gray-500 leading-relaxed">
              Utilisez cette interface pour préparer les événements qui pourront être ombrés par les organisations.
            </p>
          </div>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-4 pt-2 animate-fade-in-up delay-3">
        <.link
          navigate="/"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-600 hover:text-blue-600 bg-white hover:bg-blue-50 rounded-lg border border-gray-300 hover:border-blue-400 transition-all duration-200"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Retour à l'accueil
        </.link>
        <.link
          navigate="/org-events"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-sm transition-all duration-200"
        >
          Voir les configurations par organisation <.icon name="hero-arrow-right" class="size-4" />
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
