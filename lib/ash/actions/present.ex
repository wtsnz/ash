# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Actions.Present do
  @moduledoc false

  # Presents an action's result to its caller, hiding the fields the actor can't see.
  #
  # An action evaluates field policies for the fields it selects and loads: the authorizer adds a
  # visibility calculation for them, and `Ash.Actions.Helpers.restrict_field_access/2` consumes
  # it. A result can hold other values the actor may not see:
  #
  #   * fields of embedded resources, alone, in arrays and in unions, whose field policies a read
  #     only evaluates when it loads through them;
  #   * fields loaded before the action ran, on the record it was given or on the query of an
  #     atomic bulk action;
  #   * the values loaded for notifiers, kept in the record's calculations.
  #
  # This evaluates the field policies that are left, batched per attribute across the result
  # (or the batch, for bulk actions), cleans embedded values as a read does, and removes the
  # notifier values. Hidden embedded attributes keep their `original_value`, so the record can be
  # written back.

  alias Ash.Actions.Helpers

  @internal_calculations [
    Ash.Notifier.NotifierDependencies,
    :__ash_fields_are_visible__,
    :__ash_field_auth_check__
  ]

  @doc "Presents the result of a create, update or destroy."
  def result({:ok, record, instructions}, changeset, opts) do
    case result({:ok, record}, changeset, opts) do
      {:ok, record} -> {:ok, record, instructions}
      {:error, error} -> {:error, error}
    end
  end

  def result({:ok, record}, changeset, opts) do
    record
    |> Helpers.restrict_field_access(changeset)
    |> records(changeset.resource, present_opts(changeset, opts))
  end

  def result(other, _changeset, _opts), do: other

  @doc """
  Presents the records of one batch of a bulk action. Items that aren't records of the resource
  (errors) are kept as they are. If presenting fails, the records are replaced by the error.
  """
  def batch(items, resource, subject, opts) do
    {records, others} = Enum.split_with(items, &is_struct(&1, resource))

    case records(records, resource, present_opts(subject, opts)) do
      {:ok, records} -> {:ok, records ++ others}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Presents the return value of a generic action."
  def value(nil, _type, _constraints, _opts), do: {:ok, nil}

  def value(value, {:array, type}, constraints, opts) when is_list(value) do
    case instance_of(type, constraints[:items] || []) do
      nil -> {:ok, cleanup(value, {:array, type}, constraints, opts)}
      resource -> records(value, resource, Keyword.put(opts, :decided, :all))
    end
  end

  def value(value, type, constraints, opts) do
    case instance_of(type, constraints) do
      nil -> {:ok, cleanup(value, type, constraints, opts)}
      resource -> records(value, resource, Keyword.put(opts, :decided, :all))
    end
  end

  @doc """
  Presents records of `resource`.

  Options: `:actor`, `:tenant`, `:domain`, `:tracer`, `:authorize?`, and `:decided`, the fields
  whose field policies the action already applied (`:all` to skip evaluating top-level fields).
  """
  def records(nil, _resource, _opts), do: {:ok, nil}
  def records([], _resource, _opts), do: {:ok, []}

  def records(records, resource, opts) when is_list(records) do
    if opts[:authorize?] do
      with {:ok, records} <- undecided_fields(records, resource, opts),
           {:ok, records} <- embedded_fields(records, resource, opts) do
        {:ok, Enum.map(records, &remove_internal_calculations/1)}
      end
    else
      {:ok, Enum.map(records, &remove_internal_calculations/1)}
    end
  end

  def records(record, resource, opts) do
    case records([record], resource, opts) do
      {:ok, [record]} -> {:ok, record}
      {:error, error} -> {:error, error}
    end
  end

  # Fields the action didn't evaluate, but which are loaded on the records: values loaded before
  # the action ran. Evaluated in memory where the policies allow.
  defp undecided_fields(records, resource, opts) do
    case opts[:decided] do
      :all ->
        {:ok, records}

      decided ->
        decided = Ash.Resource.Info.primary_key(resource) ++ List.wrap(decided)

        undecided =
          resource
          |> Ash.Resource.Info.fields([:attributes, :calculations, :aggregates])
          |> Enum.map(& &1.name)
          |> Enum.reject(&(&1 in decided))
          |> Enum.filter(fn field -> Enum.any?(records, &Ash.Resource.selected?(&1, field)) end)

        if undecided == [] do
          {:ok, records}
        else
          Ash.Authorizer.apply_field_level_auth(resource, records,
            actor: opts[:actor],
            tenant: opts[:tenant],
            domain: opts[:domain],
            context: opts[:context],
            for_fields: undecided
          )
        end
    end
  end

  # Loads through each attribute holding a resource with an authorizer, as a read does, so its
  # field policies are evaluated, then cleans the values. One load per attribute for all records.
  defp embedded_fields(records, resource, opts) do
    context = %{
      domain: opts[:domain] || Ash.Resource.Info.domain(resource),
      actor: opts[:actor],
      tenant: opts[:tenant],
      tracer: opts[:tracer],
      authorize?: true
    }

    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.filter(&authorized_type?(&1.type, &1.constraints))
    |> Enum.reduce_while({:ok, records}, fn attribute, {:ok, records} ->
      case load_attribute(records, attribute, context) do
        {:ok, records} -> {:cont, {:ok, records}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp load_attribute(records, attribute, context) do
    values =
      Enum.map(records, fn record ->
        case Map.get(record, attribute.name) do
          %Ash.NotLoaded{} -> nil
          %Ash.ForbiddenField{} -> nil
          value -> value
        end
      end)

    if Enum.all?(values, &is_nil/1) do
      {:ok, records}
    else
      with {:ok, loaded} <- load_values(attribute.type, values, attribute.constraints, context) do
        {:ok,
         Enum.zip_with(records, loaded, fn record, value ->
           case Map.get(record, attribute.name) do
             %Ash.NotLoaded{} ->
               record

             %Ash.ForbiddenField{} ->
               record

             _ ->
               Map.put(
                 record,
                 attribute.name,
                 Ash.Type.rewrite(
                   attribute.type,
                   value,
                   [{:cleanup_field_auth, []}],
                   attribute.constraints
                 )
               )
           end
         end)}
      end
    end
  end

  # The read loads array attributes once per record. Here every record's items are loaded at once
  # and split up again afterwards.
  defp load_values({:array, type}, values, constraints, context) do
    lists = Enum.map(values, &(&1 || []))

    with {:ok, loaded} <-
           Ash.Type.load(type, Enum.concat(lists), [], constraints[:items] || [], context) do
      {chunks, []} =
        Enum.map_reduce(lists, loaded, fn list, rest -> Enum.split(rest, length(list)) end)

      {:ok,
       Enum.zip_with(values, chunks, fn
         nil, _ -> nil
         _, chunk -> chunk
       end)}
    end
  end

  defp load_values(type, values, constraints, context) do
    Ash.Type.load(type, values, [], constraints, context)
  end

  # Generic action results were loaded through their type by the action. This cleans them.
  defp cleanup(value, type, constraints, opts) do
    if opts[:authorize?] && Ash.Type.can_load?(type, constraints) do
      Ash.Type.rewrite(type, value, [{:cleanup_field_auth, []}], constraints)
    else
      value
    end
  end

  defp remove_internal_calculations(%{calculations: calculations} = record)
       when is_map(calculations) do
    %{
      record
      | calculations:
          Map.reject(calculations, fn
            {{key, _}, _} -> key in @internal_calculations
            _ -> false
          end)
    }
  end

  defp remove_internal_calculations(record), do: record

  defp present_opts(%{resource: resource} = subject, opts) do
    [
      actor: opts[:actor],
      tenant: Map.get(subject, :tenant) || opts[:tenant],
      domain: opts[:domain] || Ash.Resource.Info.domain(resource),
      tracer: opts[:tracer],
      authorize?: opts[:authorize?],
      # The action's own context, without its internal state (actor, authorize?), which the
      # checks set themselves.
      context: Map.delete(Map.get(subject, :context) || %{}, :private),
      decided: decided(subject)
    ]
  end

  defp decided(%Ash.Changeset{} = changeset),
    do: Ash.Changeset.accessing(changeset, [:attributes, :calculations, :aggregates], false)

  defp decided(%Ash.Query{} = query),
    do: Ash.Query.accessing(query, [:attributes, :calculations, :aggregates], false)

  defp instance_of(type, constraints) do
    if Ash.Type.get_type(type) == Ash.Type.Struct do
      case constraints[:instance_of] do
        nil ->
          nil

        resource ->
          if Ash.Resource.Info.resource?(resource), do: resource
      end
    end
  end

  # Whether a value of the type can hold a resource with an authorizer, so it may have fields to
  # hide.
  defp authorized_type?(type, constraints, seen \\ MapSet.new())

  defp authorized_type?({:array, type}, constraints, seen),
    do: authorized_type?(type, constraints[:items] || [], seen)

  defp authorized_type?(type, constraints, seen) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.NewType.new_type?(type) ->
        authorized_type?(
          Ash.Type.NewType.subtype_of(type),
          Ash.Type.NewType.constraints(type, constraints),
          seen
        )

      type == Ash.Type.Union ->
        Enum.any?(constraints[:types] || [], fn {_name, config} ->
          authorized_type?(config[:type], config[:constraints] || [], seen)
        end)

      instance_of = instance_of(type, constraints) ->
        authorized_resource?(instance_of, seen)

      Ash.Resource.Info.resource?(type) ->
        authorized_resource?(type, seen)

      true ->
        false
    end
  end

  defp authorized_resource?(resource, seen) do
    if MapSet.member?(seen, resource) do
      false
    else
      seen = MapSet.put(seen, resource)

      Ash.Resource.Info.authorizers(resource) != [] or
        Enum.any?(
          Ash.Resource.Info.attributes(resource),
          &authorized_type?(&1.type, &1.constraints, seen)
        )
    end
  end
end
