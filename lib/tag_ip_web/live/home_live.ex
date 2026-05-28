defmodule TagIpWeb.HomeLive do
  use TagIpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "global_events")

    {:ok, assign(socket, event_count: load_event_count(), org_count: load_org_count())}
  end

  @impl true
  def handle_info({:org_created, _name}, socket) do
    {:noreply, assign(socket, org_count: socket.assigns.org_count + 1)}
  end

  @impl true
  def handle_info({:event_created, _id}, socket) do
    {:noreply, assign(socket, event_count: socket.assigns.event_count + 1)}
  end

  @impl true
  def handle_info({:event_deleted, _id}, socket) do
    {:noreply, assign(socket, event_count: socket.assigns.event_count - 1)}
  end

  @impl true
  def handle_info({:event_updated, _id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  defp load_event_count, do: TagIp.Events.EventDefinition |> Ash.count!()
  defp load_org_count, do: TagIp.Accounts.Organization |> Ash.count!()
end
