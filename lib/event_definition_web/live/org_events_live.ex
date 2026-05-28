defmodule EventDefinitionWeb.OrgEventsLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(EventDefinition.PubSub, "global_events")

    orgs = load_orgs()
    default_org_id = if orgs != [], do: List.first(orgs).id, else: nil

    {:ok,
     assign(socket,
       organizations: orgs,
       selected_org_id: default_org_id,
       org_event_defs: load_org_event_defs(default_org_id),
       global_events: load_all_global_events()
     )}
  end

  @impl true
  def handle_event("select-org", %{"org_id" => org_id}, socket) do
    {:noreply,
     assign(socket,
       selected_org_id: org_id,
       org_event_defs: load_org_event_defs(org_id)
     )}
  end

  @impl true
  def handle_event("toggle-enabled", %{"id" => id}, socket) do
    binary_id = Ecto.UUID.cast!(id)
    configs = socket.assigns.org_event_defs
    target = Enum.find(configs, fn c -> to_string(c.id) == to_string(id) end)

    if target do
      new_status = !target.enabled

      from(oed in "organization_event_definitions", where: oed.id == type(^binary_id, Ecto.UUID))
      |> Repo.update_all(set: [enabled: new_status])

      updated =
        Enum.map(configs, fn c ->
          if to_string(c.id) == to_string(id), do: %{c | enabled: new_status}, else: c
        end)

      {:noreply, assign(socket, org_event_defs: updated)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:org_created, _name}, socket) do
    {:noreply, assign(socket, organizations: load_orgs())}
  end

  @impl true
  def handle_info({:event_created, _id}, socket) do
    {:noreply, assign(socket, global_events: load_all_global_events())}
  end

  @impl true
  def handle_info({:event_deleted, _id}, socket) do
    {:noreply, assign(socket, global_events: load_all_global_events())}
  end

  @impl true
  def handle_info({:global_reset, _active}, socket) do
    {:noreply,
     assign(socket, org_event_defs: load_org_event_defs(socket.assigns.selected_org_id))}
  end

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_orgs do
    from(o in "organizations",
      select: %{id: o.id, name: o.name, slug: o.slug},
      order_by: [asc: o.name]
    )
    |> Repo.all()
    |> Enum.map(fn org -> %{org | id: normalize_uuid(org.id)} end)
  end

  defp load_all_global_events do
    from(e in "event_definitions",
      select: %{
        id: e.id,
        code: e.code,
        name: e.name,
        category: e.category,
        level: e.level,
        monitor_type: e.monitor_type,
        active: e.active
      },
      order_by: e.code
    )
    |> Repo.all()
    |> Enum.map(fn evt -> %{evt | id: normalize_uuid(evt.id)} end)
  end

  defp load_org_event_defs(nil), do: []

  defp load_org_event_defs(org_id) do
    binary_org_id = Ecto.UUID.cast!(org_id)

    rows =
      from(oed in "organization_event_definitions",
        where: oed.organization_id == type(^binary_org_id, Ecto.UUID),
        select: %{
          id: oed.id,
          organization_id: oed.organization_id,
          event_definition_id: oed.event_definition_id,
          code: oed.code,
          name: oed.name,
          definition: oed.definition,
          category: oed.category,
          class: oed.class,
          level: oed.level,
          level_group: oed.level_group,
          occurrence_rule: oed.occurrence_rule,
          alert_mode: oed.alert_mode,
          enabled: oed.enabled
        },
        order_by: oed.code
      )
      |> Repo.all()
      |> Enum.map(fn oed ->
        oed
        |> Map.put(:id, normalize_uuid(oed.id))
        |> Map.put(:organization_id, normalize_uuid(oed.organization_id))
        |> then(fn oed ->
          if oed.event_definition_id do
            Map.put(oed, :event_definition_id, normalize_uuid(oed.event_definition_id))
          else
            oed
          end
        end)
      end)

    global_events = load_all_global_events()

    Enum.map(rows, fn oed ->
      if oed.event_definition_id do
        global = Enum.find(global_events, fn g -> g.id == oed.event_definition_id end)

        oed
        |> Map.put(:type, "shadow")
        |> Map.put(:resolved_name, oed.name || (global && global.name))
        |> Map.put(:resolved_category, oed.category || (global && global.category))
        |> Map.put(:resolved_level, oed.level || (global && global.level))
        |> Map.put(:has_rule, oed.occurrence_rule != nil)
      else
        oed
        |> Map.put(:type, "standalone")
        |> Map.put(:resolved_name, oed.name)
        |> Map.put(:resolved_category, oed.category)
        |> Map.put(:resolved_level, oed.level)
        |> Map.put(:has_rule, oed.occurrence_rule != nil)
      end
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
