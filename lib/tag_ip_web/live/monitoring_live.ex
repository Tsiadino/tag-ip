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
      # Supprime les noms identiques
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
      # Plus récent en premier
      |> Ash.Query.sort(inserted_at: :desc)
      # On affiche les 10 derniers
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
    # On recharge l'alerte pour s'assurer que l'organisation est présente (évite le crash KeyError)
    alert_loaded = Ash.load!(alert, [:organization])

    {:noreply,
     socket
     |> assign(alert_logs: [alert_loaded | socket.assigns.alert_logs])
     |> put_flash(:info, "Nouvelle alerte reçue : #{alert_loaded.event}")}
  end

  # Cette fonction gère le changement en temps réel des sélections (phx-change)
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

    # AUDIT : On utilise Ash.create!() pour lever une erreur si l'insertion échoue
    audit_params = %{
      user: "Fannie",
      action: "Modification Config",
      event: "Nouvelle config sauvegardée (Polling: #{params["polling_interval"]}s)"
    }

    # Note le ! après create. C'est crucial pour le debugging.
    TagIp.Events.AuditLog
    |> Ash.Changeset.for_create(:create, audit_params)
    |> Ash.create!()

    # On recharge les logs d'audit APRES l'insertion réussie
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

    # 1. On crée l'alerte
    case TagIp.Events.AlertLog
         |> Ash.Changeset.for_create(:create, alert_params)
         |> Ash.create() do
      {:ok, new_alert} ->
        # Notifications asynchrones
        spawn(fn -> Req.post(webhook_url, json: alert_params) end)
        Phoenix.PubSub.broadcast(TagIp.PubSub, "monitoring_alerts", {:new_alert, new_alert})

        # 2. AUDIT : On enregistre l'action de test
        audit_params = %{
          user: "Fannie",
          action: "Test Webhook",
          event: "Alerte test envoyée : #{alert_params.event}"
        }

        TagIp.Events.AuditLog |> Ash.Changeset.for_create(:create, audit_params) |> Ash.create()

        # 3. On recharge les audits pour l'interface
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

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="fixed top-5 right-5 z-50 flex flex-col gap-2 w-72">
        <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
          <div
            class="flex items-center gap-3 p-4 bg-emerald-50 border-l-4 border-emerald-500 text-emerald-800 rounded shadow-lg animate-bounce-in"
            role="alert"
          >
            <.icon name="hero-check-circle" class="size-5 text-emerald-500" />
            <p class="text-sm font-bold">{flash}</p>
          </div>
        <% end %>

        <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
          <div
            class="flex items-center gap-3 p-4 bg-red-50 border-l-4 border-red-500 text-red-800 rounded shadow-lg"
            role="alert"
          >
            <.icon name="hero-exclamation-triangle" class="size-5 text-red-500" />
            <p class="text-sm font-bold">{flash}</p>
          </div>
        <% end %>
      </div>

      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up">
        <div class="flex items-center gap-4 mb-4">
          <div class="size-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
            <.icon name="hero-bell-alert" class="size-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">
              Système d'Alertes et Monitoring
            </h1>
            <p class="text-sm text-gray-500 mt-0.5">
              Configurez les webhooks, emails et intervalles de polling
            </p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <div class="lg:col-span-3 bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up">
          <h2 class="text-base font-bold text-gray-900 mb-5">Configuration & Test</h2>
          <form phx-submit="update_config" phx-change="validate_config" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-600 mb-1.5">
                  Organisation à tester
                </label>
                <select
                  name="config[organization_id]"
                  class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 text-sm"
                >
                  <%= for org <- @organizations do %>
                    <option value={org.id} selected={org.id == @selected_org_id}>{org.name}</option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-xs font-semibold text-gray-600 mb-1.5">
                  Type d'événement
                </label>
                <div class="relative">
                  <select
                    name="config[event_name]"
                    class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 text-sm"
                  >
                    <%= for type <- @event_types do %>
                      <option value={type} selected={type == @selected_event}>{type}</option>
                    <% end %>
                  </select>
                </div>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-600 mb-1.5">Intervalle (s)</label>
                <input
                  type="number"
                  name="config[polling_interval]"
                  value={@monitoring_config.polling_interval}
                  class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 text-sm"
                />
              </div>
              <div class="md:col-span-2">
                <label class="block text-xs font-semibold text-gray-600 mb-1.5">URL Webhook</label>
                <input
                  type="url"
                  name="config[webhook_url]"
                  value={@monitoring_config.webhook_url}
                  class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 text-sm"
                />
              </div>
            </div>

            <div class="flex flex-wrap gap-3 pt-2">
              <button
                type="submit"
                class="bg-blue-600 text-white px-5 py-2.5 rounded-lg font-semibold text-sm"
              >
                <.icon name="hero-check" class="size-4" /> Sauvegarder config
              </button>
              <button
                type="button"
                phx-click="test_webhook"
                class="bg-gray-200 text-gray-700 px-5 py-2.5 rounded-lg font-semibold text-sm"
              >
                <.icon name="hero-paper-airplane" class="size-4" /> Envoyer Alerte Test
              </button>
            </div>
          </form>
        </div>

        <div class="lg:col-span-2 bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up delay-2">
          <h2 class="text-base font-bold text-gray-900 mb-5">Statut du système</h2>
          <div class="space-y-3">
            <div class="flex items-center gap-3 p-3.5 bg-white rounded-lg border border-gray-200 shadow-sm">
              <span class="size-2.5 rounded-full bg-blue-600 animate-pulse shadow-sm" />
              <span class="text-sm font-medium text-gray-700">Service de monitoring</span>
              <span class="ml-auto text-xs font-semibold text-blue-600 bg-blue-50 px-2.5 py-0.5 rounded-full">
                Opérationnel
              </span>
            </div>
            <div class="flex items-center gap-3 p-3.5 bg-white rounded-lg border border-gray-200 shadow-sm">
              <span class="size-2.5 rounded-full bg-blue-600 animate-pulse shadow-sm" />
              <span class="text-sm font-medium text-gray-700">Webhook endpoint</span>
              <span class="ml-auto text-xs font-semibold text-blue-600 bg-blue-50 px-2.5 py-0.5 rounded-full">
                Connecté
              </span>
            </div>
            <div class="flex items-center gap-3 p-3.5 bg-white rounded-lg border border-gray-200 shadow-sm">
              <span class="size-2.5 rounded-full bg-blue-600 animate-pulse shadow-sm" />
              <span class="text-sm font-medium text-gray-700">Email service</span>
              <span class="ml-auto text-xs font-semibold text-blue-600 bg-blue-50 px-2.5 py-0.5 rounded-full">
                Actif
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-3">
        <div class="px-6 py-4 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900">Historique des Alertes</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-200">
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Timestamp
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Événement
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                  Organisation
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Statut
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for log <- @alert_logs do %>
                <tr class="hover:bg-gray-50 transition-colors duration-150">
                  <td class="px-5 py-3.5 text-gray-500 font-mono text-xs">
                    {Calendar.strftime(log.timestamp, "%H:%M:%S")}
                  </td>
                  <td class="px-5 py-3.5 text-gray-800 font-medium">{log.event}</td>
                  <td class="px-5 py-3.5 text-gray-500 hidden sm:table-cell">
                    {if log.organization, do: log.organization.name, else: "N/A"}
                  </td>
                  <td class="px-5 py-3.5">
                    <span class={[
                      "px-2.5 py-0.5 text-xs font-semibold rounded-full",
                      log.status == "sent" && "text-blue-600 bg-blue-50 border border-blue-200",
                      log.status == "pending" && "text-gray-500 bg-gray-50 border border-gray-200"
                    ]}>
                      {if log.status == "sent", do: "Envoyé", else: "En attente"}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 animate-fade-in-up delay-4">
        <div class="px-6 py-4 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900">Audit Trail</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-200">
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Timestamp
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Action
                </th>
                <th class="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider hidden md:table-cell">
                  Événement
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for log <- @audit_logs do %>
                <tr class="hover:bg-gray-50 transition-colors duration-150">
                  <td class="px-5 py-3.5 text-gray-500 font-mono text-xs">
                    {Calendar.strftime(log.inserted_at, "%H:%M:%S")}
                  </td>

                  <td class="px-5 py-3.5">
                    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded bg-gray-100 text-gray-700">
                      <.icon name="hero-user" class="size-3" />
                      {log.user}
                    </span>
                  </td>
                  <td class="px-5 py-3.5 text-gray-700 font-medium">{log.action}</td>
                  <td class="px-5 py-3.5 text-gray-500 hidden md:table-cell">{log.event}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-4 pt-2 animate-fade-in-up delay-5">
        <.link
          navigate="/init"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-600 hover:text-blue-600 bg-white hover:bg-blue-50 rounded-lg border border-gray-300 hover:border-blue-400 transition-all duration-200"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Initialisation
        </.link>
        <.link
          navigate="/"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-sm transition-all duration-200"
        >
          Accueil <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </div>
    </section>
    """
  end
end
