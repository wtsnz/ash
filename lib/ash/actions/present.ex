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
  #   * fields of embedded resources, alone, in arrays (of any depth), in unions, NewTypes and the
  #     `fields` of maps, keywords, tuples and structs, in attributes and typed calculations;
  #   * fields loaded before the action ran, on the record it was given (including its loaded
  #     related records) or on the query of an atomic bulk action;
  #   * the values loaded for notifiers, kept in the record's calculations.
  #
  # This walks the result by type, and checks the fields that are left with
  # `Ash.Authorizer.apply_field_level_auth/3`, once per resource for the whole result (or the
  # batch, for bulk actions). Those checks run as the primary read action would, with the
  # action's actor, tenant and context, which is also how fields the action loads are checked
  # (its loads run through that action).
  #
  # Related records are only checked at field level. Whether the actor may read related records
  # that were loaded before the action isn't checked again.
  #
  # Hidden embedded attributes keep their `original_value`, so the record can be written back.
  #
  # The write has committed by the time its result is presented, so presenting never fails the
  # action: a value whose field policies can't be evaluated is hidden instead, and logged.

  require Logger

  alias Ash.Actions.Helpers

  @internal_calculations [
    Ash.Notifier.NotifierDependencies,
    :__ash_fields_are_visible__,
    :__ash_field_auth_check__
  ]

  @doc "Presents the result of a create, update or destroy."
  def result({:ok, record, instructions}, changeset, opts) do
    {:ok, record} = result({:ok, record}, changeset, opts)
    {:ok, record, instructions}
  end

  def result({:ok, record}, changeset, opts) do
    record
    |> Helpers.restrict_field_access(changeset)
    |> records(changeset.resource, present_opts(changeset, opts))
  end

  def result(other, _changeset, _opts), do: other

  @doc """
  Presents the records of one batch of a bulk action. Items that aren't records of the resource
  (errors) are kept as they are.
  """
  def batch(items, resource, subject, opts) do
    {records, others} = Enum.split_with(items, &is_struct(&1, resource))
    {:ok, records} = records(records, resource, present_opts(subject, opts))
    records ++ others
  end

  @doc "Presents the return value of a generic action."
  def value(value, type, constraints, opts) do
    opts = Keyword.put_new(opts, :context, %{})

    {item_type, item_constraints} =
      case type do
        {:array, item_type} -> {item_type, constraints[:items] || []}
        type -> {type, constraints}
      end

    case instance_of(item_type, item_constraints) do
      nil ->
        present_value(value, type, constraints, opts)

      # The action's load already checked the fields of the struct's own resource.
      resource ->
        records(value, resource, Keyword.put(opts, :decided, :all))
    end
  end

  defp present_value(value, type, constraints, opts) do
    if opts[:authorize?] do
      case safely(type, [:result], fn ->
             present_field_values(type, constraints, [value], nested_opts(opts))
           end) do
        {:ok, [value]} -> {:ok, value}
        :error -> {:ok, hide_value(value)}
      end
    else
      {:ok, value}
    end
  end

  @doc """
  Presents records of `resource`.

  Options: `:actor`, `:tenant`, `:domain`, `:tracer`, `:authorize?`, `:context`, `:decided`
  (the fields whose field policies the action already applied, or `:all`), and `:loads` (the
  related queries the action loaded, by relationship).
  """
  def records(nil, _resource, _opts), do: {:ok, nil}
  def records([], _resource, _opts), do: {:ok, []}

  def records(records, resource, opts) when is_list(records) do
    if opts[:authorize?] do
      {records, decided} = consume_visibility(records, resource, opts)

      records =
        records
        |> undecided_fields(resource, decided, opts)
        |> typed_fields(resource, opts)
        |> related_records(resource, opts)
        |> Enum.map(&remove_internal_calculations/1)

      {:ok, records}
    else
      {:ok, Enum.map(records, &remove_internal_calculations/1)}
    end
  end

  def records(record, resource, opts) do
    {:ok, [record]} = records([record], resource, opts)
    {:ok, record}
  end

  # Applies visibility the records' loads already computed (for example a generic action's
  # result loaded through its type), and treats those fields as decided.
  defp consume_visibility(records, resource, opts) do
    decided =
      Enum.flat_map(records, fn
        %{calculations: calculations} when is_map(calculations) ->
          Enum.flat_map(calculations, fn
            {{:__ash_fields_are_visible__, fields}, _} -> fields
            _ -> []
          end)

        _ ->
          []
      end)

    case decided do
      [] ->
        {records, opts[:decided]}

      decided ->
        query =
          resource
          |> Ash.Query.new()
          |> Ash.Query.set_context(%{private: %{cleaning_up_field_auth?: true}})

        records = Helpers.restrict_field_access(records, query)

        case opts[:decided] do
          :all -> {records, :all}
          other -> {records, Enum.uniq(List.wrap(other) ++ decided)}
        end
    end
  end

  # Fields the action didn't evaluate, but which are loaded on the records: values loaded before
  # the action ran, and every field of nested records. Evaluated in memory where the policies
  # allow, with one query per resource for filter checks that need the data layer.
  defp undecided_fields(records, _resource, :all, _opts), do: records

  defp undecided_fields(records, resource, decided, opts) do
    decided = Ash.Resource.Info.primary_key(resource) ++ List.wrap(decided)

    undecided =
      resource
      |> Ash.Resource.Info.fields([:attributes, :calculations, :aggregates])
      |> Enum.map(& &1.name)
      |> Enum.reject(&(&1 in decided))
      |> Enum.filter(fn field -> Enum.any?(records, &Ash.Resource.selected?(&1, field)) end)

    if undecided == [] do
      records
    else
      result =
        safely(resource, undecided, fn ->
          Ash.Authorizer.apply_field_level_auth(resource, records,
            actor: opts[:actor],
            tenant: opts[:tenant],
            domain: opts[:domain] || Ash.Resource.Info.domain(resource),
            context: opts[:context],
            for_fields: undecided
          )
        end)

      case result do
        {:ok, records} -> records
        :error -> Enum.map(records, &hide_fields(&1, undecided))
      end
    end
  end

  # Attributes and calculations whose type can hold a resource with an authorizer. One pass per
  # field for all records.
  defp typed_fields(records, resource, opts) do
    fields =
      Ash.Resource.Info.attributes(resource) ++ Ash.Resource.Info.calculations(resource)

    fields
    |> Enum.filter(&authorized_type?(&1.type, &1.constraints))
    |> Enum.reduce(records, fn field, records ->
      values = Enum.map(records, &Map.get(&1, field.name))

      result =
        safely(resource, [field.name], fn ->
          present_field_values(field.type, field.constraints, values, nested_opts(opts))
        end)

      case result do
        {:ok, values} -> Enum.zip_with(records, values, &Map.put(&1, field.name, &2))
        :error -> Enum.map(records, &hide_fields(&1, [field.name]))
      end
    end)
  end

  # Loaded related records, at field level. Records the action loaded were checked by that load;
  # their fields are presented with the related query, so they aren't checked again.
  defp related_records(records, resource, opts) do
    resource
    |> Ash.Resource.Info.relationships()
    |> Enum.reduce(records, fn relationship, records ->
      values = Enum.map(records, &Map.get(&1, relationship.name))
      related = Enum.flat_map(values, &related_list/1)

      if related == [] do
        records
      else
        destination = relationship.destination

        related_opts =
          case Keyword.get(opts[:loads] || [], relationship.name) do
            %Ash.Query{} = query ->
              Keyword.merge(opts, decided: accessing(query), loads: query.load)

            _ ->
              nested_opts(opts)
          end
          |> Keyword.put(:domain, Ash.Resource.Info.domain(destination) || opts[:domain])

        {:ok, presented} = records(related, destination, related_opts)

        {values, []} = Enum.map_reduce(values, presented, &put_related/2)
        Enum.zip_with(records, values, &Map.put(&1, relationship.name, &2))
      end
    end)
  end

  defp related_list(%struct{results: results}) when struct in [Ash.Page.Keyset, Ash.Page.Offset],
    do: results

  defp related_list(list) when is_list(list), do: list
  defp related_list(%Ash.NotLoaded{}), do: []
  defp related_list(%Ash.ForbiddenField{}), do: []
  defp related_list(%_{} = record), do: [record]
  defp related_list(_), do: []

  defp put_related(%struct{results: results} = page, presented)
       when struct in [Ash.Page.Keyset, Ash.Page.Offset] do
    {results, rest} = Enum.split(presented, length(results))
    {%{page | results: results}, rest}
  end

  defp put_related(list, presented) when is_list(list), do: Enum.split(presented, length(list))
  defp put_related(%Ash.NotLoaded{} = value, presented), do: {value, presented}
  defp put_related(%Ash.ForbiddenField{} = value, presented), do: {value, presented}
  defp put_related(%_{}, [record | rest]), do: {record, rest}
  defp put_related(value, presented), do: {value, presented}

  # Presents a list of values of the type, keeping their shape. Placeholders and nils are left as
  # they are.
  defp present_field_values(type, constraints, values, opts) do
    if authorized_type?(type, constraints) do
      {present, indexes} =
        values
        |> Enum.with_index()
        |> Enum.reject(fn {value, _} -> placeholder?(value) end)
        |> Enum.unzip()

      with {:ok, presented} <- present_values(type, constraints, present, opts) do
        by_index = Map.new(Enum.zip(indexes, presented))

        {:ok,
         values
         |> Enum.with_index()
         |> Enum.map(fn {value, index} -> Map.get(by_index, index, value) end)}
      end
    else
      {:ok, values}
    end
  end

  defp present_values(_type, _constraints, [], _opts), do: {:ok, []}

  # Every list's items are presented at once, then split up again, so each array dimension is
  # kept.
  defp present_values({:array, type}, constraints, lists, opts) do
    lists = Enum.map(lists, &List.wrap/1)

    with {:ok, items} <-
           present_field_values(type, constraints[:items] || [], Enum.concat(lists), opts) do
      {chunks, []} = Enum.map_reduce(lists, items, &Enum.split(&2, length(&1)))
      {:ok, chunks}
    end
  end

  defp present_values(type, constraints, values, opts) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.NewType.new_type?(type) ->
        present_field_values(
          Ash.Type.NewType.subtype_of(type),
          Ash.Type.NewType.constraints(type, constraints),
          values,
          opts
        )

      type == Ash.Type.Union ->
        present_union(values, constraints, opts)

      resource = instance_of(type, constraints) ->
        records(values, resource, opts)

      Ash.Resource.Info.resource?(type) ->
        records(values, type, opts)

      is_list(constraints[:fields]) ->
        present_fields(type, constraints[:fields], values, opts)

      true ->
        {:ok, values}
    end
  end

  defp present_union(values, constraints, opts) do
    types = constraints[:types] || []

    values
    |> Enum.with_index()
    |> Enum.group_by(fn
      {%Ash.Union{type: name}, _} -> name
      _ -> nil
    end)
    |> Enum.reduce_while({:ok, %{}}, fn
      {nil, group}, {:ok, acc} ->
        {:cont, {:ok, Enum.into(group, acc, fn {value, index} -> {index, value} end)}}

      {name, group}, {:ok, acc} ->
        config = types[name] || []
        inner = Enum.map(group, fn {%Ash.Union{value: value}, _} -> value end)

        case present_field_values(config[:type], config[:constraints] || [], inner, opts) do
          {:ok, inner} ->
            acc =
              group
              |> Enum.zip(inner)
              |> Enum.into(acc, fn {{union, index}, value} -> {index, %{union | value: value}} end)

            {:cont, {:ok, acc}}

          other ->
            {:halt, other}
        end
    end)
    |> case do
      {:ok, by_index} ->
        {:ok, Enum.map(0..(length(values) - 1)//1, &Map.fetch!(by_index, &1))}

      other ->
        other
    end
  end

  # The `fields` of maps, keywords, tuples and structs.
  defp present_fields(type, fields, values, opts) do
    fields
    |> Enum.with_index()
    |> Enum.filter(fn {{_name, config}, _} ->
      authorized_type?(config[:type], config[:constraints] || [])
    end)
    |> Enum.reduce_while({:ok, values}, fn {{name, config}, index}, {:ok, values} ->
      field_values = Enum.map(values, &get_field(type, &1, name, index))

      case present_field_values(config[:type], config[:constraints] || [], field_values, opts) do
        {:ok, field_values} ->
          {:cont,
           {:ok, Enum.zip_with(values, field_values, &put_field(type, &1, name, index, &2))}}

        other ->
          {:halt, other}
      end
    end)
  end

  defp get_field(Ash.Type.Tuple, value, _name, index) when is_tuple(value) do
    if tuple_size(value) > index, do: elem(value, index)
  end

  defp get_field(Ash.Type.Keyword, value, name, _index) when is_list(value),
    do: Keyword.get(value, name)

  defp get_field(_type, value, name, _index) when is_map(value), do: Map.get(value, name)
  defp get_field(_type, _value, _name, _index), do: nil

  defp put_field(_type, value, _name, _index, nil), do: value

  defp put_field(Ash.Type.Tuple, value, _name, index, field_value) when is_tuple(value),
    do: put_elem(value, index, field_value)

  defp put_field(Ash.Type.Keyword, value, name, _index, field_value) when is_list(value),
    do: List.keyreplace(value, name, 0, {name, field_value})

  defp put_field(_type, value, name, _index, field_value) when is_map(value) do
    if Map.has_key?(value, name), do: Map.put(value, name, field_value), else: value
  end

  defp put_field(_type, value, _name, _index, _field_value), do: value

  defp placeholder?(nil), do: true
  defp placeholder?(%Ash.NotLoaded{}), do: true
  defp placeholder?(%Ash.ForbiddenField{}), do: true
  defp placeholder?(_), do: false

  # Records nested in a value are checked in full: none of their fields were checked by the
  # action.
  defp nested_opts(opts), do: Keyword.merge(opts, decided: [], loads: [])

  # Runs a presentation step. A step that fails, or raises, hides what it was presenting.
  defp safely(source, fields, fun) do
    case fun.() do
      {:ok, value} ->
        {:ok, value}

      {:error, error} ->
        log_hidden(source, fields, Ash.Error.to_ash_error(error))
        :error
    end
  rescue
    error ->
      log_hidden(source, fields, error)
      :error
  end

  defp log_hidden(source, fields, error) do
    Logger.warning("""
    Couldn't check the field policies of #{inspect(source)} #{inspect(fields)} in an action \
    result, so they're hidden: #{Exception.message(error)}
    """)
  end

  defp hide_fields(record, fields) do
    embedded? = Ash.Resource.Info.embedded?(record.__struct__)

    Enum.reduce(fields, record, fn field, record ->
      case Map.get(record, field) do
        nil ->
          record

        %Ash.NotLoaded{} ->
          record

        %Ash.ForbiddenField{} ->
          record

        value ->
          type =
            case Ash.Resource.Info.field(record.__struct__, field) do
              %Ash.Resource.Aggregate{} -> :aggregate
              %Ash.Resource.Calculation{} -> :calculation
              _ -> :attribute
            end

          original_value = if embedded? && type == :attribute, do: value

          Map.put(record, field, %Ash.ForbiddenField{
            field: field,
            type: type,
            original_value: original_value
          })
      end
    end)
  end

  defp hide_value(nil), do: nil
  defp hide_value(_value), do: %Ash.ForbiddenField{field: :result, type: :calculation}

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
    query = loaded_query(subject)

    [
      actor: opts[:actor],
      tenant: Map.get(subject, :tenant) || opts[:tenant],
      domain: opts[:domain] || Ash.Resource.Info.domain(resource),
      tracer: opts[:tracer],
      authorize?: opts[:authorize?],
      # The action's own context, without its internal state (actor, authorize?), which the
      # checks set themselves.
      context: Map.delete(Map.get(subject, :context) || %{}, :private),
      decided: accessing(query),
      loads: query.load
    ]
  end

  defp loaded_query(%Ash.Changeset{} = changeset) do
    changeset.resource
    |> Ash.Query.new()
    |> Ash.Query.load(changeset.load)
    |> Map.put(:select, changeset.select)
  end

  defp loaded_query(%Ash.Query{} = query), do: query

  defp accessing(query),
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

  defp authorized_type?(nil, _constraints, _seen), do: false

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

      is_list(constraints[:fields]) ->
        Enum.any?(constraints[:fields], fn {_name, config} ->
          authorized_type?(config[:type], config[:constraints] || [], seen)
        end)

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
          Ash.Resource.Info.attributes(resource) ++ Ash.Resource.Info.calculations(resource),
          &authorized_type?(&1.type, &1.constraints, seen)
        )
    end
  end
end
