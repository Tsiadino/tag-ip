defmodule TagIpWeb.OrgEventsLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
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
    organizations_list =
      Repo.all(from(o in "organizations", select: o.name, order_by: [asc: o.id]))

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
    updated_events = Enum.map(socket.assigns.events, &%{&1 | enabled: status, active: status})
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

    Phoenix.PubSub.broadcast(
      TagIp.PubSub,
      "global_events",
      {:global_event_toggled, id, new_status}
    )

    updated_events =
      Enum.map(events, fn event ->
        if to_string(event.id) == to_string(id),
          do: %{event | enabled: new_status, active: new_status},
          else: event
      end)

    {:noreply, assign(socket, events: updated_events)}
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
