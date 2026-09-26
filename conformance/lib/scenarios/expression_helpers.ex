# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.ExpressionHelpers do
  @moduledoc """
  Declarations for the expression scenarios. They are macros, so each
  scenario's source link points at the line that declares it.
  """

  @basis "../documentation/topics/reference/expressions.md"
  @text [allow_empty?: true, trim?: false]

  @doc "An expression read as a calculation on each of the four rows."
  defmacro calc(id, type, expression, expected, requires) do
    quote do
      Ash.Conformance.Scenario.new(
        unquote(id),
        :expressions,
        Ash.Conformance.Scenarios.ExpressionHelpers.by_row(unquote(expected)),
        Ash.Conformance.Scenarios.ExpressionHelpers.calculated(
          unquote(type),
          unquote(expression)
        ),
        Ash.Conformance.Scenarios.ExpressionHelpers.opts(unquote(requires))
      )
    end
  end

  @doc "The IDs of the rows an expression keeps as a filter."
  defmacro filter(id, expression, expected, requires) do
    quote do
      Ash.Conformance.Scenario.new(
        unquote(id),
        :filters,
        unquote(expected),
        &Ash.Conformance.Scenarios.ExpressionHelpers.ids(&1, unquote(expression)),
        Ash.Conformance.Scenarios.ExpressionHelpers.opts(unquote(requires))
      )
    end
  end

  def by_row(values), do: Map.new(Enum.zip(1..4, Enum.map(values, &project/1)))

  def calculated(type, expression) do
    constraints = if type == :string, do: @text, else: []

    fn ctx ->
      ctx.adapter.resource(:expr_row)
      |> Ash.Query.calculate(:result, type, expression, %{}, constraints)
      |> Ash.Query.sort(:id)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, project(&1.calculations.result)})
    end
  end

  def ids(ctx, expression) do
    ctx.adapter.resource(:expr_row)
    |> Ash.Query.do_filter(expression)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  def opts(requires), do: [fixture: :expressions, requires: requires, semantic_basis: @basis]

  @doc "Floats rounded to six places; datetimes by value; CiStrings as strings."
  def project(value) when is_float(value), do: Float.round(value, 6)
  def project(%DateTime{} = value), do: {:datetime, DateTime.to_unix(value, :microsecond)}
  def project(%Ash.CiString{} = value), do: to_string(value)
  def project(value), do: value
end
