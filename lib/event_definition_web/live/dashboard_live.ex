defmodule EventDefinitionWeb.DashboardLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(EventDefinition.PubSub, "global_events")

    {:ok, assign_dashboard(socket)}
  end

  @impl true
  def handle_event("dismiss_alert", %{"id" => id}, socket) do
    alerts = Enum.reject(socket.assigns.alerts, &(to_string(&1.id) == id))
    {:noreply, assign(socket, :alerts, alerts)}
  end

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket) do
    {:noreply, assign_dashboard(socket)}
  end

  @impl true
  def handle_info({:global_reset, _active}, socket) do
    {:noreply, assign_dashboard(socket)}
  end

  @impl true
  def handle_info({:event_created, _id}, socket), do: {:noreply, assign_dashboard(socket)}
  @impl true
  def handle_info({:event_updated, _id}, socket), do: {:noreply, assign_dashboard(socket)}
  @impl true
  def handle_info({:event_deleted, _id}, socket), do: {:noreply, assign_dashboard(socket)}
  @impl true
  def handle_info({:org_created, _name}, socket), do: {:noreply, assign_dashboard(socket)}
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_dashboard(socket) do
    events = load_events()
    orgs = load_orgs()
    org_event_defs = load_org_event_defs()
    audit_logs = load_audit_logs()

    global_count = length(events)
    active_global_count = Enum.count(events, & &1.active)
    inactive_global_count = global_count - active_global_count
    org_count = length(orgs)
    total_configs = length(org_event_defs)
    enabled_configs = Enum.count(org_event_defs, & &1.enabled)
    standalone_count = Enum.count(org_event_defs, &is_nil(&1.event_definition_id))
    with_rules_count = Enum.count(org_event_defs, & &1.occurrence_rule)

    stats = %{
      global_count: global_count,
      active_global_count: active_global_count,
      inactive_global_count: inactive_global_count,
      org_count: org_count,
      total_configs: total_configs,
      enabled_configs: enabled_configs,
      standalone_count: standalone_count,
      with_rules_count: with_rules_count
    }

    assign(socket,
      stats: stats,
      events: events,
      organizations: orgs,
      org_event_defs: org_event_defs,
      audit_logs: audit_logs,
      alerts: []
    )
  end

  defp load_events do
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
  end

  defp load_orgs do
    from(o in "organizations",
      select: %{id: o.id, name: o.name, slug: o.slug},
      order_by: [asc: o.name]
    )
    |> Repo.all()
    |> Enum.map(fn org -> %{org | id: normalize_uuid(org.id)} end)
  end

  defp load_org_event_defs do
    from(oed in "organization_event_definitions",
      select: %{
        id: oed.id,
        organization_id: oed.organization_id,
        event_definition_id: oed.event_definition_id,
        code: oed.code,
        enabled: oed.enabled,
        occurrence_rule: oed.occurrence_rule
      }
    )
    |> Repo.all()
    |> Enum.map(fn oed ->
      %{oed | id: normalize_uuid(oed.id), organization_id: normalize_uuid(oed.organization_id)}
    end)
    |> Enum.map(fn oed ->
      if oed.event_definition_id do
        %{oed | event_definition_id: normalize_uuid(oed.event_definition_id)}
      else
        oed
      end
    end)
  end

  defp load_audit_logs do
    from(al in "audit_logs",
      select: %{
        id: al.id,
        user: al.user,
        action: al.action,
        event: al.event,
        inserted_at: al.inserted_at
      },
      order_by: [desc: al.inserted_at],
      limit: 15
    )
    |> Repo.all()
    |> Enum.map(fn log -> %{log | id: normalize_uuid(log.id)} end)
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
