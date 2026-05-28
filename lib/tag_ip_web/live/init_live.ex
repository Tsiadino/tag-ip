defmodule TagIpWeb.InitLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 1, from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    {:ok, refresh_all_data(socket)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  @impl true
  def handle_event("select-org", %{"org_id" => org_id}, socket) do
    suggestions = build_suggestions(org_id)

    {:noreply,
     socket
     |> assign(:selected_org_id, org_id)
     |> assign(:suggestions, suggestions)
     |> assign(:selected_ids, suggestions |> Enum.filter(& &1.recommended) |> Enum.map(& &1.id))}
  end

  @impl true
  def handle_event("toggle-suggestion", %{"id" => id}, socket) do
    current = socket.assigns.selected_ids

    updated =
      if id in current do
        List.delete(current, id)
      else
        [id | current]
      end

    {:noreply, assign(socket, :selected_ids, updated)}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    ids = Enum.map(socket.assigns.suggestions, & &1.id)
    {:noreply, assign(socket, :selected_ids, ids)}
  end

  @impl true
  def handle_event("select-recommended", _params, socket) do
    ids = socket.assigns.suggestions |> Enum.filter(& &1.recommended) |> Enum.map(& &1.id)
    {:noreply, assign(socket, :selected_ids, ids)}
  end

  @impl true
  def handle_event("deselect-all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, [])}
  end

  @impl true
  def handle_event("apply-init", _params, socket) do
    org_id = socket.assigns.selected_org_id
    selected_ids = socket.assigns.selected_ids

    if org_id && selected_ids != [] do
      count = initialize_org(org_id, selected_ids)

      Phoenix.PubSub.broadcast(
        TagIp.PubSub,
        "global_events",
        {:org_created, org_id}
      )

      {:noreply,
       socket
       |> put_flash(:info, "#{count} configuration(s) créée(s) avec succès !")
       |> refresh_all_data()}
    else
      {:noreply,
       put_flash(socket, :error, "Sélectionnez une organisation et au moins un événement")}
    end
  end

  @impl true
  def handle_event("add_org", _params, socket) do
    count = Repo.aggregate(from(o in "organizations"), :count, :id)
    new_id = count + 1
    name = "Organization #{new_id}"
    slug = "org_#{new_id}"
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("organizations", [
      [
        name: name,
        slug: slug,
        inserted_at: now,
        updated_at: now
      ]
    ])

    Phoenix.PubSub.broadcast(
      TagIp.PubSub,
      "global_events",
      {:org_created, name}
    )

    {:noreply,
     socket
     |> put_flash(:info, "#{name} créée !")
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

  @impl true
  def handle_info({:event_created, _id}, socket), do: {:noreply, refresh_all_data(socket)}
  @impl true
  def handle_info({:event_updated, _id}, socket), do: {:noreply, refresh_all_data(socket)}
  @impl true
  def handle_info({:event_deleted, _id}, socket), do: {:noreply, refresh_all_data(socket)}
  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket),
    do: {:noreply, refresh_all_data(socket)}

  @impl true
  def handle_info({:global_reset, _active}, socket), do: {:noreply, refresh_all_data(socket)}
  @impl true
  def handle_info({:org_created, _name}, socket), do: {:noreply, refresh_all_data(socket)}
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp refresh_all_data(socket) do
    total = Repo.aggregate(from(e in "event_definitions"), :count, :id)
    active = Repo.aggregate(from(e in "event_definitions", where: e.active == true), :count, :id)

    orgs =
      from(o in "organizations",
        select: %{id: o.id, name: o.name, slug: o.slug},
        order_by: [asc: o.name]
      )
      |> Repo.all()
      |> Enum.map(fn org -> %{org | id: normalize_uuid(org.id)} end)

    events =
      from(e in "event_definitions",
        select: %{
          id: e.id,
          code: e.code,
          name: e.name,
          category: e.category,
          class: e.class,
          level: e.level,
          level_group: e.level_group,
          monitor_type: e.monitor_type,
          active: e.active
        },
        order_by: [asc: e.code]
      )
      |> Repo.all()
      |> Enum.map(fn evt -> %{evt | id: normalize_uuid(evt.id)} end)

    socket =
      socket
      |> assign(
        total_events: total,
        active_events: active,
        organizations: orgs,
        events: events,
        selected_org_id: nil,
        suggestions: [],
        selected_ids: []
      )

    socket
  end

  defp build_suggestions(org_id) do
    binary_org_id = Ecto.UUID.cast!(org_id)

    existing_codes =
      from(oed in "organization_event_definitions",
        where: oed.organization_id == type(^binary_org_id, Ecto.UUID),
        select: oed.code
      )
      |> Repo.all()

    events =
      from(e in "event_definitions",
        select: %{
          id: e.id,
          code: e.code,
          name: e.name,
          category: e.category,
          class: e.class,
          level: e.level,
          level_group: e.level_group,
          monitor_type: e.monitor_type,
          active: e.active
        },
        order_by: [asc: e.code]
      )
      |> Repo.all()
      |> Enum.map(fn evt -> %{evt | id: normalize_uuid(evt.id)} end)

    Enum.map(events, fn evt ->
      %{
        id: evt.id,
        code: evt.code,
        name: evt.name,
        category: evt.category,
        class: evt.class,
        level: evt.level,
        level_group: evt.level_group,
        monitor_type: evt.monitor_type,
        already_configured: evt.code in existing_codes,
        recommended: evt.level == 1 && evt.category != "system" && !(evt.code in existing_codes)
      }
    end)
  end

  defp initialize_org(org_id, selected_ids) do
    binary_org_id = Ecto.UUID.cast!(org_id)

    existing_codes =
      from(oed in "organization_event_definitions",
        where: oed.organization_id == type(^binary_org_id, Ecto.UUID),
        select: oed.code
      )
      |> Repo.all()
      |> MapSet.new()

    events =
      from(e in "event_definitions",
        where: e.id in type(^Enum.map(selected_ids, &Ecto.UUID.cast!/1), {:array, Ecto.UUID}),
        select: %{id: e.id, code: e.code},
        order_by: [asc: e.code]
      )
      |> Repo.all()
      |> Enum.map(fn evt -> %{evt | id: normalize_uuid(evt.id)} end)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    new_configs =
      events
      |> Enum.reject(fn evt -> evt.code in existing_codes end)
      |> Enum.map(fn evt ->
        %{
          organization_id: binary_org_id,
          event_definition_id: evt.id,
          code: evt.code,
          name: nil,
          definition: nil,
          category: nil,
          class: nil,
          level: nil,
          level_group: nil,
          occurrence_rule: nil,
          alert_mode: "none",
          enabled: true,
          author_id: binary_org_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    if new_configs != [] do
      Repo.insert_all("organization_event_definitions", new_configs)
    end

    length(new_configs)
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
