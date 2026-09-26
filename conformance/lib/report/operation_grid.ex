# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.OperationGrid do
  @moduledoc """
  The tier-2 grid in reports: each operation on each type. A cell counts
  against the type only when the same operation works on integers and the
  type stores; otherwise it is blocked, shown as ◌. `markdown/1` is the
  overview across data layers; `detail/1` is one data layer's type ×
  operation table.
  """
  alias Ash.Conformance.{Operations, Storage}

  @legend """
  ✅ returns the answer Ash defines; ❌ does not, while the same operation
  works on integers and the type stores; ◌ blocked: the operation fails on
  integers too, or the type does not store; ❔ did not run; – does not apply
  to the type.
  """

  @doc "Type × data layer overview."
  def markdown(results) do
    ran = Enum.reject(results, & &1.unavailable)

    rows =
      Enum.map_join(Storage.types(), "\n", fn type ->
        "| #{type.label} | #{Enum.map_join(ran, " | ", &summary(&1.rows, type.name))} |"
      end)

    """
    ## Operations

    Tier 2: every filter, sort and aggregate on every type it applies to,
    over the type's tier-1 table (`lib/operations.ex`). Integers are the
    control. Counts are cells that work, out of those not blocked; ◌ counts
    the blocked ones. Each data layer's survey file has the full type ×
    operation table.

    #{String.trim(@legend)}

    | Type | #{Enum.map_join(ran, " | ", & &1.adapter.id())} |
    | --- | #{Enum.map_join(ran, " | ", fn _ -> "---" end)} |
    #{rows}
    """
  end

  @doc "One data layer's type × operation table."
  def detail(rows) do
    by_id = Map.new(rows, &{&1.scenario, &1})
    operations = Operations.operations()

    body =
      Enum.map_join(Storage.types(), "\n", fn type ->
        cells = Enum.map_join(operations, " | ", &marker(by_id, type.name, &1))
        "| #{type.label} | #{cells} |"
      end)

    """
    ## Operations

    #{String.trim(@legend)}

    | Type | #{Enum.map_join(operations, " | ", &"`#{&1}`")} |
    | --- | #{Enum.map_join(operations, " | ", fn _ -> "---" end)} |
    #{body}
    """
  end

  defp summary(rows, name) do
    by_id = Map.new(rows, &{&1.scenario, &1})

    cells =
      for operation <- Operations.operations(),
          (marker = marker(by_id, name, operation)) != "–",
          do: marker

    judged = Enum.count(cells, &(&1 in ["✅", "❌"]))
    passing = Enum.count(cells, &(&1 == "✅"))
    blocked = Enum.count(cells, &(&1 == "◌"))
    unknown = Enum.count(cells, &(&1 == "❔"))

    icon =
      cond do
        cells == [] -> "–"
        unknown == length(cells) -> "❔"
        passing == judged and blocked == 0 and unknown == 0 -> "✅"
        passing == judged and blocked > 0 -> "◌"
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

  defp marker(by_id, name, operation) do
    case Map.get(by_id, Operations.scenario_id(name, operation)) do
      nil -> "–"
      %{classification: :works} -> "✅"
      %{classification: :setup_failed} -> "❔"
      %{blocked_by: [_ | _]} -> "◌"
      _row -> "❌"
    end
  end
end
