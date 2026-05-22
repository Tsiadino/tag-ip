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
  def handle_info({:event_created, _id}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info({:event_updated, _id}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info({:event_deleted, _id}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info({:global_reset, _active}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info({:org_created, _name}, socket) do
    {:noreply, refresh_all_data(socket)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp refresh_all_data(socket) do
    total = Repo.aggregate(from(e in "event_definitions"), :count, :id)
    active = Repo.aggregate(from(e in "event_definitions", where: e.active == true), :count, :id)

    orgs = Repo.all(from(o in "organizations", select: o.name, order_by: [asc: o.id]))

    assign(socket,
      total_events: total,
      active_events: active,
      organizations: orgs
    )
  end
end