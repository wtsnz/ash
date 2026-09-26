# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Tiers do
  @moduledoc """
  Which layer of the suite a scenario belongs to, so a report can say
  whether a failure is in one type, one operation, one feature or a
  combination.

  - Tier 1, storage: each type stored and read back (`storage.*`).
  - Tier 2, operations: each filter, sort and aggregate on each type
    (`ops.*`).
  - Expressions: each expression function, and nil logic, on one small
    fixture (`expr.*`, `nil.*`).
  - The policy grid: each policy shape on each path (`policy.*`).
  - The combination grid: features alone and in pairs (`combo.*`).
  - Tier 4, integration: every other scenario. These run on the richly
    typed fixtures and usually exercise several features at once, so read a
    failure here after the grids above. (Tier 3, core-typed fixtures, was
    dropped; see `CONFORMANCE_PLAN_v3.md`.)
  """

  @tiers [
    {:storage, "Storage (tier 1)", "storage."},
    {:operations, "Operations (tier 2)", "ops."},
    {:expressions, "Expressions", ["expr.", "nil."]},
    {:policies, "Policy grid", "policy."},
    {:combinations, "Combinations", "combo."},
    {:integration, "Integration (tier 4)", nil}
  ]

  def all, do: Enum.map(@tiers, fn {tier, label, _prefix} -> {tier, label} end)

  def of(scenario_id) do
    Enum.find_value(@tiers, :integration, fn
      {tier, _label, prefix} when not is_nil(prefix) ->
        if String.starts_with?(scenario_id, prefix), do: tier

      _tier ->
        nil
    end)
  end

  @doc "Tier × data layer: passing out of what ran, then blocked and not run."
  def markdown(results) do
    ran = Enum.reject(results, & &1.unavailable)

    rows =
      Enum.map_join(all(), "\n", fn {tier, label} ->
        "| #{label} | #{Enum.map_join(ran, " | ", &cell(&1.rows, tier))} |"
      end)

    """
    ## By tier

    Read from the top: a failure in a lower tier explains failures above it.
    Each cell counts scenarios that work, out of those that ran, then the
    failures that have a failing prerequisite (blocked), and those that
    could not run.

    | Tier | #{Enum.map_join(ran, " | ", & &1.adapter.id())} |
    | --- | #{Enum.map_join(ran, " | ", fn _ -> "---" end)} |
    #{rows}
    """
  end

  defp cell(rows, tier) do
    case Enum.filter(rows, &(of(&1.scenario) == tier)) do
      [] -> "– not included"
      rows -> counts(rows)
    end
  end

  defp counts(rows) do
    not_run = Enum.count(rows, &(&1.classification == :setup_failed))
    ran = length(rows) - not_run
    works = Enum.count(rows, &(&1.classification == :works))

    blocked =
      Enum.count(
        rows,
        &(&1.classification not in [:works, :setup_failed] and Map.get(&1, :blocked_by, []) != [])
      )

    [
      "#{works}/#{ran}",
      if(blocked > 0, do: "#{blocked} blocked"),
      if(not_run > 0, do: "#{not_run} not run")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end
end
