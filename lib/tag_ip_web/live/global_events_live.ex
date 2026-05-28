defmodule TagIpWeb.GlobalEventsLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")
    end

    {:ok,
     assign(socket,
       events: load_events(),
       filter: "all"
     )}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter, events: load_events(filter))}
  end

  @impl true
  def handle_event("toggle-active", %{"id" => id}, socket) do
    binary_id = Ecto.UUID.cast!(id)

    events = socket.assigns.events
    target_event = Enum.find(events, fn e -> to_string(e.id) == to_string(id) end)

    if target_event do
      new_status = !target_event.active

      from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
      |> Repo.update_all(set: [active: new_status])

      Phoenix.PubSub.broadcast(
        TagIp.PubSub,
        "global_events",
        {:global_event_toggled, id, new_status}
      )

      updated_events =
        Enum.map(events, fn event ->
          if to_string(event.id) == to_string(id) do
            %{event | active: new_status}
          else
            event
          end
        end)

      {:noreply, assign(socket, events: updated_events)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:event_created, _id}, socket) do
    {:noreply, assign(socket, events: load_events(socket.assigns.filter))}
  end

  @impl true
  def handle_info({:event_updated, _id}, socket) do
    {:noreply, assign(socket, events: load_events(socket.assigns.filter))}
  end

  @impl true
  def handle_info({:event_deleted, _id}, socket) do
    {:noreply, assign(socket, events: load_events(socket.assigns.filter))}
  end

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket) do
    {:noreply, assign(socket, events: load_events(socket.assigns.filter))}
  end

  @impl true
  def handle_info({:global_reset, _active}, socket) do
    {:noreply, assign(socket, events: load_events(socket.assigns.filter))}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_events(filter \\ "all") do
    events =
      if filter != "all" do
        from(e in "event_definitions",
          where: e.category == type(^filter, :string),
          select: %{
            id: e.id,
            code: e.code,
            name: e.name,
            definition: e.definition,
            category: e.category,
            class: e.class,
            level: e.level,
            level_group: e.level_group,
            monitor_type: e.monitor_type,
            active: e.active
          },
          order_by: e.code
        )
        |> Repo.all()
      else
        from(e in "event_definitions",
          select: %{
            id: e.id,
            code: e.code,
            name: e.name,
            definition: e.definition,
            category: e.category,
            class: e.class,
            level: e.level,
            level_group: e.level_group,
            monitor_type: e.monitor_type,
            active: e.active
          },
          order_by: e.code
        )
        |> Repo.all()
      end
      |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)

    org_counts =
      from(oed in "organization_event_definitions",
        select: %{event_definition_id: oed.event_definition_id, count: count(oed.id)},
        group_by: oed.event_definition_id
      )
      |> Repo.all()
      |> Map.new(fn %{event_definition_id: eid, count: cnt} -> {normalize_uuid(eid), cnt} end)

    Enum.map(events, fn event ->
      Map.put(event, :org_count, Map.get(org_counts, event.id, 0))
    end)
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
