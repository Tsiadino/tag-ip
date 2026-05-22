defmodule TagIpWeb.MonitoringLive do
  use TagIpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TagIp.PubSub, "monitoring_alerts")

    # 1. Récupération des organisations
    organizations = TagIp.Accounts.Organization |> Ash.read!()

    # 2. Récupération DYNAMIQUE (Depuis le CSV importé en DB)
    event_types =
      TagIp.Events.EventDefinition
      |> Ash.read!()
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    # 3. Chargement de l'historique
    alert_logs =
      TagIp.Events.AlertLog
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.load([:organization])
      |> Ash.read!()

    # 4. Chargement de l'Audit Trail
    audit_logs =
      TagIp.Events.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    monitoring_config = %{
      polling_interval: 30,
      webhook_url: "https://webhook.site/7e5a7841-0982-411c-83bd-7a7ce6bd7483",
      email_alert: "fannie@tag-ip.com",
      logs_enabled: true
    }

    {:ok,
     assign(socket,
       organizations: organizations,
       event_types: event_types,
       selected_org_id: (List.first(organizations) || %{id: nil}).id,
       selected_event: List.first(event_types) || "Aucun événement disponible",
       alert_logs: alert_logs,
       audit_logs: audit_logs,
       monitoring_config: monitoring_config
     )}
  end

  @impl true
  def handle_info({:new_alert, alert}, socket) do
    alert_loaded = Ash.load!(alert, [:organization])

    {:noreply,
     socket
     |> assign(alert_logs: [alert_loaded | socket.assigns.alert_logs])
     |> put_flash(:info, "Nouvelle alerte reçue : #{alert_loaded.event}")}
  end

  @impl true
  def handle_event("validate_config", %{"config" => params}, socket) do
    {:noreply,
     assign(socket,
       selected_org_id: params["organization_id"],
       selected_event: params["event_name"]
     )}
  end

  @impl true
  def handle_event("update_config", %{"config" => params}, socket) do
    new_config = %{
      polling_interval: String.to_integer(params["polling_interval"]),
      webhook_url: params["webhook_url"],
      email_alert: params["email_alert"],
      logs_enabled: params["logs_enabled"] == "true"
    }

    audit_params = %{
      user: "Fannie",
      action: "Modification Config",
      event: "Nouvelle config sauvegardée (Polling: #{params["polling_interval"]}s)"
    }

    TagIp.Events.AuditLog
    |> Ash.Changeset.for_create(:create, audit_params)
    |> Ash.create!()

    updated_audit_logs =
      TagIp.Events.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    {:noreply,
     socket
     |> assign(monitoring_config: new_config, audit_logs: updated_audit_logs)
     |> assign(selected_org_id: params["organization_id"])
     |> assign(selected_event: params["event_name"])
     |> put_flash(:info, "Configuration mise à jour et auditée avec succès")}
  end

  @impl true
  def handle_event("test_webhook", _params, socket) do
    webhook_url = socket.assigns.monitoring_config.webhook_url

    alert_params = %{
      event: socket.assigns.selected_event,
      organization_id: socket.assigns.selected_org_id,
      status: "sent",
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case TagIp.Events.AlertLog
         |> Ash.Changeset.for_create(:create, alert_params)
         |> Ash.create() do
      {:ok, new_alert} ->
        spawn(fn -> Req.post(webhook_url, json: alert_params) end)
        Phoenix.PubSub.broadcast(TagIp.PubSub, "monitoring_alerts", {:new_alert, new_alert})

        audit_params = %{
          user: "Fannie",
          action: "Test Webhook",
          event: "Alerte test envoyée : #{alert_params.event}"
        }

        TagIp.Events.AuditLog |> Ash.Changeset.for_create(:create, audit_params) |> Ash.create()

        updated_audit_logs =
          TagIp.Events.AuditLog |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!()

        {:noreply,
         socket
         |> assign(audit_logs: updated_audit_logs)
         |> put_flash(:info, "Signal envoyé et audité pour #{alert_params.event} !")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur d'enregistrement PostgreSQL")}
    end
  end
end
