defmodule TagIpWeb.MonitoringLive do
  use TagIpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       monitoring_config: %{
         polling_interval: 30,
         webhook_url: "https://webhook.site/demo_corp",
         email_alert: "admin@demo.com",
         logs_enabled: true
       },
       alert_logs: [
         %{
           id: 1,
           timestamp: "2026-05-07 15:30:00",
           event: "Vitesse > 90 km/h",
           organization: "demo_corp",
           status: "sent"
         },
         %{
           id: 2,
           timestamp: "2026-05-07 15:25:00",
           event: "Freinage brusque",
           organization: "org_1",
           status: "sent"
         },
         %{
           id: 3,
           timestamp: "2026-05-07 15:20:00",
           event: "Arrivée détectée",
           organization: "demo_corp",
           status: "pending"
         }
       ],
       audit_logs: [
         %{
           id: 1,
           timestamp: "2026-05-07 15:00:00",
           user: "admin",
           action: "Activé événement",
           event: "Vitesse > 90 km/h"
         },
         %{
           id: 2,
           timestamp: "2026-05-07 14:45:00",
           user: "admin",
           action: "Désactivé événement",
           event: "Freinage brusque"
         },
         %{
           id: 3,
           timestamp: "2026-05-07 14:30:00",
           user: "admin",
           action: "Modifié configuration",
           event: "Monitoring config"
         }
       ]
     )}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    {:noreply, put_flash(socket, :info, "Toutes les notifications ont été marquées comme lues")}
  end

  @impl true
  def handle_event("update_config", %{"config" => params}, socket) do
    # On extrait et convertit proprement les valeurs
    polling_int = 
      params["polling_interval"] 
      |> case do
        nil -> socket.assigns.monitoring_config.polling_interval
        val when is_binary(val) -> String.to_integer(val)
        val -> val
      end

    new_config = %{
      polling_interval: polling_int,
      webhook_url: params["webhook_url"] || socket.assigns.monitoring_config.webhook_url,
      email_alert: params["email_alert"] || socket.assigns.monitoring_config.email_alert,
      logs_enabled: params["logs_enabled"] == "true"
    }

    {:noreply,
    socket
    |> put_flash(:info, "✅ Configuration mise à jour")
    |> assign(monitoring_config: new_config)}
  end

  @impl true
  def handle_event("test_webhook", _params, socket) do
    # Simulation d'un appel HTTP vers l'URL configurée
    url = socket.assigns.monitoring_config.webhook_url
    
    # Dans ton mémoire, tu pourrais expliquer qu'ici on utilise :
    # HTTPoison.post(url, "{\"test\": \"ok\"}", [{"Content-Type", "application/json"}])
    
    {:noreply, 
    socket 
    |> put_flash(:info, "🚀 Signal envoyé à : #{url}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
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
        <div class="lg:col-span-3 bg-white rounded-xl p-6 shadow-sm border border-gray-200 animate-fade-in-up delay-1">
          <h2 class="text-base font-bold text-gray-900 mb-5">Configuration</h2>
          <form phx-submit="update_config" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1.5">
                Intervalle de polling (secondes)
              </label>
              <input
                type="number"
                name="config[polling_interval]"
                value={@monitoring_config.polling_interval}
                class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all outline-none text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1.5">URL Webhook</label>
              <input
                type="url"
                name="config[webhook_url]"
                value={@monitoring_config.webhook_url}
                class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all outline-none text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1.5">Email d'alerte</label>
              <input
                type="email"
                name="config[email_alert]"
                value={@monitoring_config.email_alert}
                class="w-full px-3.5 py-2.5 rounded-lg border-2 border-gray-200 bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all outline-none text-sm"
              />
            </div>
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="hidden" name="config[logs_enabled]" value="false" />
              <input
                type="checkbox"
                name="config[logs_enabled]"
                checked={@monitoring_config.logs_enabled}
                value="true"
                class="size-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer"
              />
              <span class="text-sm font-semibold text-gray-700">Logs activés</span>
            </label>
            <div class="flex flex-wrap gap-3 pt-2">
              <button
                type="submit"
                class="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-all duration-200 text-sm shadow-sm"
              >
                <.icon name="hero-check" class="size-4" /> Mettre à jour
              </button>
              <button
                type="button"
                phx-click="test_webhook"
                class="inline-flex items-center gap-2 px-5 py-2.5 bg-gray-200 hover:bg-gray-300 text-gray-700 font-semibold rounded-lg transition-all duration-200 text-sm"
              >
                <.icon name="hero-paper-airplane" class="size-4" /> Tester Webhook
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
                  <td class="px-5 py-3.5 text-gray-500 font-mono text-xs">{log.timestamp}</td>
                  <td class="px-5 py-3.5 text-gray-800 font-medium">{log.event}</td>
                  <td class="px-5 py-3.5 text-gray-500 hidden sm:table-cell">{log.organization}</td>
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
                  <td class="px-5 py-3.5 text-gray-500 font-mono text-xs">{log.timestamp}</td>
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
