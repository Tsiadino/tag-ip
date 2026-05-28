defmodule TagIpWeb.OrgEventConfigLive do
  use TagIpWeb, :live_view

  alias TagIp.Repo
  import Ecto.Query, only: [from: 2]

  @spec_classes ~w(movement power fuel geofence driver alarm connectivity)
  @spec_level_groups ~w(movement power fuel geofence driver alarm connectivity speed geofence poi)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    oed = load_org_event_def(id)

    if oed do
      form =
        oed
        |> Map.take([
          :code,
          :name,
          :definition,
          :category,
          :class,
          :level,
          :level_group,
          :occurrence_rule,
          :alert_mode,
          :enabled
        ])
        |> Map.update!(:category, fn
          nil -> ""
          val -> to_string(val)
        end)
        |> Map.update!(:class, fn
          nil -> ""
          val -> to_string(val)
        end)
        |> Map.update!(:alert_mode, fn
          nil -> "none"
          val -> to_string(val)
        end)
        |> Map.update!(:occurrence_rule, fn
          nil -> "{}"
          val when is_map(val) -> Jason.encode!(val)
          val -> val
        end)
        |> Map.new(fn {k, v} -> {to_string(k), v} end)
        |> then(fn attrs -> to_form(attrs, as: :org_event_definition) end)

      {:ok,
       socket
       |> assign(:form, form)
       |> assign(:oed_id, id)
       |> assign(:oed, oed)
       |> assign(:codes, distinct_values(:code))
       |> assign(:names, distinct_values(:name))
       |> assign(:classes, Enum.uniq(distinct_values(:class) ++ @spec_classes))
       |> assign(:level_groups, Enum.uniq(distinct_values(:level_group) ++ @spec_level_groups))
       |> assign(:definitions, distinct_values(:definition))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Configuration introuvable")
       |> push_navigate(to: ~p"/org-events")}
    end
  end

  @impl true
  def handle_event("validate", %{"org_event_definition" => params}, socket) do
    form =
      params
      |> then(fn p -> to_form(p, as: :org_event_definition) end)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"org_event_definition" => params}, socket) do
    binary_id = Ecto.UUID.cast!(socket.assigns.oed_id)

    params =
      params
      |> Map.update("occurrence_rule", %{}, &parse_json_map/1)
      |> Map.update("category", "", fn v ->
        if v == "", do: nil, else: String.to_existing_atom(v)
      end)
      |> Map.update("class", "", fn v -> if v == "", do: nil, else: String.to_existing_atom(v) end)
      |> Map.update("alert_mode", "none", &String.to_existing_atom/1)
      |> Map.update("level", nil, fn v -> if v == "", do: nil, else: String.to_integer(v) end)
      |> Map.update("enabled", "false", fn v -> v == "true" end)

    case update_org_event_def(binary_id, params) do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          TagIp.PubSub,
          "global_events",
          {:global_reset, :all}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Configuration mise à jour")
         |> push_navigate(to: ~p"/org-events")}

      {:error, error} ->
        message = "Erreur : #{Exception.message(error)}"
        form = to_form(params, as: :org_event_definition)

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    binary_id = Ecto.UUID.cast!(socket.assigns.oed_id)

    {_count, _} =
      from(oed in "organization_event_definitions", where: oed.id == type(^binary_id, Ecto.UUID))
      |> Repo.delete_all()

    Phoenix.PubSub.broadcast(
      TagIp.PubSub,
      "global_events",
      {:global_reset, :all}
    )

    {:noreply,
     socket
     |> put_flash(:info, "Configuration supprimée")
     |> push_navigate(to: ~p"/org-events")}
  end

  defp load_org_event_def(id) do
    binary_id = Ecto.UUID.cast!(id)

    from(oed in "organization_event_definitions",
      where: oed.id == type(^binary_id, Ecto.UUID),
      select: %{
        id: oed.id,
        code: oed.code,
        name: oed.name,
        definition: oed.definition,
        category: oed.category,
        class: oed.class,
        level: oed.level,
        level_group: oed.level_group,
        occurrence_rule: oed.occurrence_rule,
        alert_mode: oed.alert_mode,
        enabled: oed.enabled
      }
    )
    |> Repo.one()
    |> case do
      nil ->
        nil

      result ->
        result
        |> Map.put(:id, normalize_uuid(result.id))
    end
  end

  defp update_org_event_def(binary_id, params) do
    update_fields =
      params
      |> Map.take([
        "code",
        "name",
        "definition",
        "category",
        "class",
        "level",
        "level_group",
        "occurrence_rule",
        "alert_mode",
        "enabled"
      ])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    from(oed in "organization_event_definitions",
      where: oed.id == type(^binary_id, Ecto.UUID)
    )
    |> Repo.update_all(set: update_fields)

    {:ok, binary_id}
  rescue
    e -> {:error, e}
  end

  defp parse_json_map(nil), do: %{}
  defp parse_json_map(""), do: %{}

  defp parse_json_map(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp parse_json_map(map) when is_map(map), do: map

  defp distinct_values(field) do
    from(e in "event_definitions",
      select: field(e, ^field),
      distinct: true,
      order_by: field(e, ^field)
    )
    |> Repo.all()
    |> Enum.reject(fn v -> is_nil(v) or v == "" end)
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
