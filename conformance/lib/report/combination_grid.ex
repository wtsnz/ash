# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.CombinationGrid do
  @moduledoc """
  The combination grid in reports. Each feature alone, then the pairwise
  cases. A pairwise case counts against the combination only when every
  feature it combines works alone; otherwise it is blocked, shown as ◌.
  `markdown/1` is the overview across data layers; `detail/1` lists one
  data layer's pairwise cases.
  """
  alias Ash.Conformance.Combinations

  @legend """
  ✅ returns the answer Ash defines; ❌ does not, while each feature it
  combines works alone; ◌ blocked: one of those features fails alone; 🔀 the
  answer changes with the order rows were stored in; ❔ did not run.
  """

  @doc "Single cases, then the pairs, × data layer."
  def markdown(results) do
    # Only data layers that opt in to the combination fixture run it.
    ran =
      Enum.filter(results, fn result ->
        is_nil(result.unavailable) and
          Enum.any?(result.rows, &String.starts_with?(&1.scenario, "combo."))
      end)

    skipped = for result <- results, result not in ran, do: result.adapter.id()
    {singles, pairs} = split()

    rows =
      Enum.map(singles, fn test_case ->
        "| #{label(test_case)} | #{Enum.map_join(ran, " | ", &marker(by_id(&1.rows), test_case))} |"
      end) ++
        ["| **Pairs** | #{Enum.map_join(ran, " | ", &summary(&1.rows, pairs))} |"]

    """
    ## Combinations

    Aggregates combined with relationship shapes, aggregate filters, tenants,
    policies and how the result is used (`lib/combinations.ex`). Each feature
    runs alone first; the #{length(pairs)} pairwise cases cover every pair of
    feature values at least once. Each data layer's survey file lists them.
    #{not_included(skipped)}
    #{String.trim(@legend)}

    | Case | #{Enum.map_join(ran, " | ", & &1.adapter.id())} |
    | --- | #{Enum.map_join(ran, " | ", fn _ -> "---" end)} |
    #{Enum.join(rows, "\n")}
    """
  end

  defp not_included([]), do: ""

  defp not_included(ids),
    do:
      "\nNot included for #{Enum.map_join(ids, ", ", &"`#{&1}`")}: the grid runs on the data " <>
        "layers that opt in to its fixture (`fixture?(:combination)`).\n"

  @doc "One data layer's pairwise cases, or nothing if it does not run them."
  def detail(rows) do
    if Enum.any?(rows, &String.starts_with?(&1.scenario, "combo.")),
      do: pairs_table(rows),
      else: ""
  end

  defp pairs_table(rows) do
    by_id = by_id(rows)
    {_singles, pairs} = split()
    axes = Keyword.keys(Combinations.axes())

    body =
      Enum.map_join(pairs, "\n", fn test_case ->
        "| #{Enum.map_join(axes, " | ", &"`#{test_case[&1]}`")} | #{marker(by_id, test_case)} |"
      end)

    """
    ## Combinations

    #{String.trim(@legend)}

    | #{Enum.map_join(axes, " | ", &to_string/1)} | Result |
    | #{Enum.map_join(axes, " | ", fn _ -> "---" end)} | --- |
    #{body}
    """
  end

  defp split, do: Enum.split_with(Combinations.cases(), &(length(Combinations.changed(&1)) <= 1))

  defp label(test_case) do
    case Combinations.changed(test_case) do
      [] ->
        "base: " <>
          Enum.map_join(Combinations.axes(), ", ", fn {axis, [v | _]} -> "#{axis} #{v}" end)

      [axis] ->
        "#{axis}: #{test_case[axis]}"
    end
  end

  defp by_id(rows), do: Map.new(rows, &{&1.scenario, &1})

  defp summary(rows, pairs) do
    by_id = by_id(rows)
    cells = Enum.map(pairs, &marker(by_id, &1))
    judged = Enum.count(cells, &(&1 in ["✅", "❌", "🔀"]))
    passing = Enum.count(cells, &(&1 == "✅"))
    blocked = Enum.count(cells, &(&1 == "◌"))
    unknown = Enum.count(cells, &(&1 == "❔"))

    icon =
      cond do
        unknown == length(cells) -> "❔"
        passing == judged and blocked == 0 and unknown == 0 -> "✅"
        passing == judged -> "◌"
        true -> "❌"
      end

    [
      "#{icon} #{passing}/#{judged}",
      if(blocked > 0, do: "#{blocked} ◌"),
      if(unknown > 0, do: "#{unknown} ❔")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp marker(by_id, test_case) do
    case Map.get(by_id, Combinations.scenario_id(test_case)) do
      nil -> "–"
      %{classification: :works} -> "✅"
      %{classification: :setup_failed} -> "❔"
      %{blocked_by: [_ | _]} -> "◌"
      %{classification: :order_dependent} -> "🔀"
      _row -> "❌"
    end
  end
end
