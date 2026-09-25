# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Generated do
  @moduledoc """
  A bounded, seeded set of filtered aggregates checked against an in-memory
  reference over the literal aggregate fixture.

  The reference only filters and folds child values; it does not model any
  query planner. Changing the seed or case count changes the cases, so both are
  part of the scenario description and the result lists every failing case.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query

  @seed {2026, 9, 25}
  @count 24
  @kinds [:count, :sum, :min, :max, :exists]
  @comparisons [:gt, :gte, :lt]

  def all do
    [
      new("generated.filtered_aggregates", :aggregates, [], &mismatches/1,
        description:
          "#{@count} cases from seed #{inspect(@seed)}: loaded and root aggregates filtered by child value",
        semantic_basis: "../documentation/topics/resources/aggregates.md"
      )
    ]
  end

  @doc "The generated cases, reproducible from the fixed seed."
  def cases do
    state = :rand.seed_s(:exsss, @seed)

    {cases, _} =
      Enum.map_reduce(1..@count, state, fn index, state ->
        {scope, state} = pick([:loaded, :root], state)
        {kind, state} = pick(@kinds, state)
        {comparison, state} = pick(@comparisons, state)
        {threshold, state} = :rand.uniform_s(9, state)

        {%{
           index: index,
           scope: scope,
           kind: kind,
           comparison: comparison,
           threshold: threshold - 1
         }, state}
      end)

    cases
  end

  defp pick(values, state) do
    {index, state} = :rand.uniform_s(length(values), state)
    {Enum.at(values, index - 1), state}
  end

  defp mismatches(ctx) do
    Enum.flat_map(cases(), fn test_case ->
      actual = observe(ctx, test_case)
      expected = reference(test_case)
      if actual == expected, do: [], else: [{test_case, expected: expected, actual: actual}]
    end)
  end

  defp observe(ctx, %{scope: :loaded} = test_case) do
    ctx.parent
    |> Ash.Query.aggregate(:result, test_case.kind, :children, aggregate_opts(test_case))
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1.aggregates.result})
  end

  defp observe(ctx, %{scope: :root} = test_case) do
    Ash.aggregate!(ctx.child, [{:result, test_case.kind, aggregate_opts(test_case)}],
      authorize?: false
    ).result
  end

  defp aggregate_opts(test_case) do
    field = if test_case.kind in [:count, :exists], do: [], else: [field: :value]
    field ++ [query: [filter: [value: [{test_case.comparison, test_case.threshold}]]]]
  end

  defp reference(%{scope: :loaded} = test_case) do
    Map.new([1, 2, 3], fn parent_id ->
      {parent_id,
       Ash.Conformance.Fixtures.children()
       |> Enum.filter(&(&1.parent_id == parent_id))
       |> fold(test_case)}
    end)
  end

  defp reference(%{scope: :root} = test_case),
    do: fold(Ash.Conformance.Fixtures.children(), test_case)

  defp fold(children, test_case) do
    values =
      children
      |> Enum.map(& &1.value)
      |> Enum.filter(&(not is_nil(&1) and compare(&1, test_case)))

    case {test_case.kind, values} do
      {:count, values} -> length(values)
      {:exists, values} -> values != []
      {_, []} -> nil
      {:sum, values} -> Enum.sum(values)
      {:min, values} -> Enum.min(values)
      {:max, values} -> Enum.max(values)
    end
  end

  defp compare(value, %{comparison: :gt, threshold: threshold}), do: value > threshold
  defp compare(value, %{comparison: :gte, threshold: threshold}), do: value >= threshold
  defp compare(value, %{comparison: :lt, threshold: threshold}), do: value < threshold
end
