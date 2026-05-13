defmodule TagIpWeb.LoginLive do
  use TagIpWeb, :live_view
  import Ash.Query

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(trigger_submit: false)
     |> assign_form(%{"email" => ""}),
     layout: {TagIpWeb.Layouts, :auth}}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div :if={flash = Phoenix.Flash.get(@flash, :error)} class="mb-6 p-4 text-sm text-red-700 bg-red-50 rounded-xl border border-red-100 font-medium text-center">
        {flash}
      </div>

      <header class="text-center mb-8">
        <h1 class="text-2xl font-black tracking-tight text-slate-900 uppercase">Connexion</h1>
        <p class="text-[10px] text-slate-500 font-bold uppercase tracking-widest mt-2">
          Accédez à votre tableau de bord TagIp
        </p>
      </header>

      <.form
        for={@form}
        id="login_form"
        action={~p"/login"}
        phx-submit="prepare_login"
        phx-trigger-action={@trigger_submit}
        class="space-y-6"
      >
        <div class="space-y-2">
          <label class="block text-[10px] font-black text-slate-500 uppercase tracking-widest">Email</label>
          <input 
            type="email" 
            name="login[email]" 
            value={@form[:email].value} 
            class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition-all text-sm" 
            required 
          />
        </div>

        <div class="space-y-2">
          <label class="block text-[10px] font-black text-slate-500 uppercase tracking-widest">Mot de passe</label>
          <input 
            type="password" 
            name="login[password]" 
            class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition-all text-sm" 
            required 
          />
        </div>

        <div class="flex items-center justify-center">
          <.link
            navigate="/reset-password"
            class="text-[10px] font-bold text-slate-400 hover:text-blue-600 uppercase tracking-widest transition-colors"
          >
            Mot de passe oublié ?
          </.link>
        </div>

        <button 
          type="submit" 
          class="w-full py-4 bg-[#0840A5] hover:bg-[#063284] text-white text-xs font-black rounded-xl uppercase tracking-widest transition-all shadow-lg shadow-blue-900/10"
        >
          Se connecter
        </button>
      </.form>
    </div>
    """
  end

  def handle_event("prepare_login", %{"login" => params}, socket) do
    email = params["email"]

    # Utilisation d'Ash pour vérifier si l'utilisateur existe
    # On suppose que ton identifiant est l'email
    exists? =
      TagIp.Accounts.User
      |> filter(email == ^email)
      |> Ash.read_one()
      |> case do
        {:ok, nil} -> false
        {:ok, _user} -> true
        _ -> false
      end

    if exists? do
      # Si l'utilisateur existe, on déclenche l'action POST vers le contrôleur
      {:noreply, socket |> assign(trigger_submit: true) |> assign_form(params)}
    else
      {:noreply,
      socket
      |> put_flash(:error, "Identifiants invalides")
      |> assign_form(params)}
    end
  end

  defp assign_form(socket, params) do
    assign(socket, :form, to_form(params, as: "login"))
  end
end