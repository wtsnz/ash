# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.RecordHelpers do
  @moduledoc """
  Declarations and projections for the scenarios on the `record` role.

  The declaring helpers are macros, so each scenario's source link points at
  the line that declares it rather than at this module.
  """

  @expressions "../documentation/topics/reference/expressions.md"
  @reads "../documentation/topics/actions/read-actions.md"
  @attributes "../documentation/topics/resources/attributes.md"

  defmacro scenario(id, area, expected, basis, run) do
    quote do
      Ash.Conformance.Scenario.new(unquote(id), unquote(area), unquote(expected), unquote(run),
        fixture: :records,
        semantic_basis: unquote(basis)
      )
    end
  end

  @doc "A filter over every record, compared by sorted ID."
  defmacro filter(id, expected, expression) do
    quote do
      Ash.Conformance.Scenarios.RecordHelpers.scenario(
        unquote(id),
        :filters,
        unquote(expected),
        unquote(@expressions),
        fn ctx ->
          ctx
          |> Ash.Conformance.Scenarios.RecordHelpers.query()
          |> Ash.Query.do_filter(unquote(expression))
          |> Ash.Conformance.Scenarios.RecordHelpers.ids()
        end
      )
    end
  end

  @doc "A sort, optionally over a filtered subset, compared by ID order."
  defmacro sort(id, expected, sort, filter \\ nil) do
    filtered =
      if filter,
        do: quote(do: Ash.Query.do_filter(var!(query, __MODULE__), unquote(filter))),
        else: quote(do: var!(query, __MODULE__))

    quote do
      Ash.Conformance.Scenarios.RecordHelpers.scenario(
        unquote(id),
        :ordering,
        unquote(expected),
        unquote(@reads),
        fn ctx ->
          var!(query, __MODULE__) = Ash.Query.sort(ctx.record, unquote(sort))

          unquote(filtered) |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
        end
      )
    end
  end

  @doc "Writes a group of attributes, then reads them back in a fresh query."
  defmacro round_trip(id, attributes) do
    quote do
      attributes = unquote(attributes)

      Ash.Conformance.Scenarios.RecordHelpers.scenario(
        unquote(id),
        :types,
        Ash.Conformance.Scenarios.RecordHelpers.project(attributes),
        unquote(@attributes),
        fn ctx ->
          Ash.create!(ctx.record, Map.merge(%{id: 9, code: "rt"}, attributes), authorize?: false)

          ctx.record
          |> Ash.get!(9, authorize?: false)
          |> Map.take(Map.keys(attributes))
          |> Ash.Conformance.Scenarios.RecordHelpers.project()
        end
      )
    end
  end

  # Embedded records compare by their attributes.
  def project(values) do
    Map.new(values, fn
      {key, %Ash.Conformance.Resources.Address{} = address} ->
        {key, Map.take(address, [:city, :zip])}

      {key, value} ->
        {key, value}
    end)
  end

  def error_shape({:error, %class{errors: errors}}),
    do: {class, errors |> Enum.map(&{&1.__struct__, Map.get(&1, :field)}) |> Enum.sort()}

  def error_shape(other), do: {:unexpected, other}

  def page(ctx, opts) do
    ctx.record
    |> Ash.Query.for_read(:paged)
    |> Ash.Query.sort(:id)
    |> Ash.read!(page: opts, authorize?: false)
  end

  def query(ctx), do: Ash.Query.sort(ctx.record, :id)

  def ids(query), do: query |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
end
