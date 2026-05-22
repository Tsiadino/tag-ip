defmodule TagIpWeb.LoginLive do
  use TagIpWeb, :live_view
  import Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(trigger_submit: false)
     |> assign_form(%{"email" => ""}), layout: {TagIpWeb.Layouts, :auth}}
  end

  @impl true
  def handle_event("prepare_login", %{"login" => params}, socket) do
    email = params["email"]

    # Utilisation d'Ash pour vérifier si l'utilisateur existe
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
