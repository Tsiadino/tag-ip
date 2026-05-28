defmodule EventDefinitionWeb.EventEditLive do
  use EventDefinitionWeb, :live_view
  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @spec_classes ~w(movement power fuel geofence driver alarm connectivity)
  @spec_level_groups ~w(movement power fuel geofence driver alarm connectivity speed geofence poi)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    event = Ash.get!(EventDefinition.Events.EventDefinition, id, domain: EventDefinition.Domain)

    form =
      event
      |> Map.from_struct()
      |> Map.take([
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :monitor_type,
        :active
      ])
      |> Map.update!(:category, &to_string/1)
      |> Map.update!(:class, &to_string/1)
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> then(fn attrs -> to_form(attrs, as: :event_definition) end)

    org_count =
      from(oed in "organization_event_definitions",
        where: oed.event_definition_id == type(^Ecto.UUID.cast!(event.id), Ecto.UUID)
      )
      |> Repo.aggregate(:count)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:event_id, id)
      |> assign(:preview, %{})
      |> assign(:org_count, org_count)
      |> assign(:codes, distinct_values(:code))
      |> assign(:names, distinct_values(:name))
      |> assign(:monitor_types, distinct_values(:monitor_type))
      |> assign(:classes, Enum.uniq(distinct_values(:class) ++ @spec_classes))
      |> assign(:level_groups, Enum.uniq(distinct_values(:level_group) ++ @spec_level_groups))
      |> assign(:definitions, distinct_values(:definition))

    {:ok, socket}
  end

  defp distinct_values(field) do
    from(e in "event_definitions",
      select: field(e, ^field),
      distinct: true,
      order_by: field(e, ^field)
    )
    |> Repo.all()
    |> Enum.reject(fn v -> is_nil(v) or v == "" end)
  end

  @impl true
  def handle_event("preview", %{"event_definition" => params}, socket) do
    {:noreply, assign(socket, :preview, params)}
  end

  @impl true
  def handle_event("save", %{"event_definition" => params}, socket) do
    event =
      Ash.get!(EventDefinition.Events.EventDefinition, socket.assigns.event_id,
        domain: EventDefinition.Domain
      )

    case Ash.update(event, params, domain: EventDefinition.Domain) do
      {:ok, _updated} ->
        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "global_events",
          {:event_updated, socket.assigns.event_id}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Événement mis à jour avec succès")
         |> push_navigate(to: ~p"/global-events")}

      {:error, error} ->
        errors = extract_errors(error)
        message = build_error_message(errors, params)
        form = to_form(params, as: :event_definition, errors: errors)

        {:noreply,
         socket
         |> assign(form: form)
         |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    event =
      Ash.get!(EventDefinition.Events.EventDefinition, socket.assigns.event_id,
        domain: EventDefinition.Domain
      )

    case Ash.destroy(event, domain: EventDefinition.Domain) do
      :ok ->
        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "global_events",
          {:event_deleted, socket.assigns.event_id}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Événement supprimé")
         |> push_navigate(to: ~p"/global-events")}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, "Erreur lors de la suppression : #{Exception.message(error)}")}
    end
  end

  defp build_error_message(errors, params) do
    code = params["code"]

    duplicate =
      Enum.find(errors, fn {field, msg} ->
        String.contains?(String.downcase(msg), [
          "already",
          "unique",
          "existe",
          "contrainte",
          "duplicate"
        ]) or
          (field == "code" and
             String.contains?(String.downcase(msg), ["pris", "existe", "utilisé"]))
      end)

    if duplicate do
      "❌ Le code « #{code} » existe déjà dans le catalogue global"
    else
      msg = Enum.map_join(errors, "; ", fn {_field, msg} -> msg end)
      "Erreur : #{msg}"
    end
  end

  defp extract_errors(error) do
    case error do
      %{changeset: %{errors: field_errors}} when is_list(field_errors) ->
        Enum.flat_map(field_errors, fn field_error ->
          case field_error do
            {field, {message, _opts}} ->
              [{to_string(field), message}]

            %{field: field, message: message} when not is_nil(field) ->
              [{to_string(field), message}]

            other ->
              [{field_name(other), Exception.message(other)}]
          end
        end)

      %{errors: field_errors} when is_list(field_errors) ->
        Enum.flat_map(field_errors, fn field_error ->
          case field_error do
            {field, {message, _opts}} ->
              [{to_string(field), message}]

            %{field: field, message: message} when not is_nil(field) ->
              [{to_string(field), message}]

            other ->
              [{field_name(other), Exception.message(other)}]
          end
        end)

      %{message: message} ->
        [{"base", message}]

      _ ->
        [{"base", Exception.message(error)}]
    end
  end

  defp field_name(%{field: field}) when not is_nil(field), do: to_string(field)
  defp field_name(%{input: input}) when is_binary(input), do: input
  defp field_name(_), do: "base"
end
