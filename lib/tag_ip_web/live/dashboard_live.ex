defmodule TagIpWeb.DashboardLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    {:ok,
     assign(socket,
       events: load_events(),
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

    events =
      Enum.map(socket.assigns.events, fn event ->
        %{event | active: active, enabled: active}
      end)

    {:noreply,
     socket
     |> assign(:events, events)
     |> assign(:alerts, [alert | socket.assigns.alerts])}
  end

  @impl true
  def handle_info({:event_created, _id}, socket) do
    {:noreply, assign(socket, events: load_events())}
  end

  @impl true
  def handle_info({:event_updated, _id}, socket) do
    {:noreply, assign(socket, events: load_events())}
  end

  @impl true
  def handle_info({:event_deleted, _id}, socket) do
    {:noreply, assign(socket, events: load_events())}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

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
    |> Enum.map(&Map.put(&1, :enabled, &1.active))
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end