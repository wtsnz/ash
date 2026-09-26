# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.PolicyGrid do
  @moduledoc """
  The policy grid in reports: each policy case on each path. A cell counts
  against the policy only when the same path works without authorization:
  each cell requires its path's control, so a failing control blocks it and
  the path itself is the problem, shown as ◌.
  `markdown/1` is the overview across data layers; `detail/1` is one data
  layer's case × path table.
  """
  alias Ash.Conformance.Policy

  @legend """
  ✅ returns the answer Ash's policy semantics define; ❌ does not, while the
  same path works without authorization; ◌ the path fails even without
  authorization, so the policy cannot be judged; ❔ did not run; – does not
  apply, such as getting a hidden record when the actor may read every note.
  """

  @doc "Case × data layer overview."
  def markdown(results) do
    ran = Enum.reject(results, & &1.unavailable)

    rows =
      Enum.map_join(rows_spec(), "\n", fn {case_id, label} ->
        "| #{label} | #{Enum.map_join(ran, " | ", &summary(&1.rows, case_id))} |"
      end)

    """
    ## Policies

    Every policy shape Ash documents, on every path a data layer implements.
    Expected answers come from a reference model of Ash's policy semantics
    (`lib/policy.ex`). Counts are policy cells that work, out of those whose
    path works without authorization; ◌ counts the rest. Each data layer's
    survey file has the full case × path table.

    #{String.trim(@legend)}

    | Case | #{Enum.map_join(ran, " | ", & &1.adapter.id())} |
    | --- | #{Enum.map_join(ran, " | ", fn _ -> "---" end)} |
    #{rows}
    """
  end

  @doc "One data layer's case × path table."
  def detail(rows) do
    by_id = Map.new(rows, &{&1.scenario, &1})
    paths = Policy.paths() ++ Policy.field_paths() ++ Policy.create_paths()

    body =
      Enum.map_join(rows_spec(), "\n", fn {case_id, label} ->
        "| #{label} | #{Enum.map_join(paths, " | ", &marker(by_id, case_id, &1))} |"
      end)

    """
    ## Policies

    #{String.trim(@legend)}

    | Case | #{Enum.map_join(paths, " | ", &"`#{&1}`")} |
    | --- | #{Enum.map_join(paths, " | ", fn _ -> "---" end)} |
    #{body}
    """
  end

  defp rows_spec do
    Enum.map(Policy.cases(), fn {case_id, _, _} -> {case_id, case_id} end) ++
      [{"field", "field"}, {"control", "control (no authorization)"}]
  end

  defp summary(rows, case_id) do
    by_id = Map.new(rows, &{&1.scenario, &1})

    cells =
      for path <- Policy.paths() ++ Policy.field_paths() ++ Policy.create_paths(),
          (marker = marker(by_id, case_id, path)) != "–",
          do: marker

    judged = Enum.count(cells, &(&1 in ["✅", "❌"]))
    passing = Enum.count(cells, &(&1 == "✅"))
    path = Enum.count(cells, &(&1 == "◌"))
    unknown = Enum.count(cells, &(&1 == "❔"))

    icon =
      cond do
        cells == [] -> "–"
        unknown == length(cells) -> "❔"
        passing == judged and path == 0 and unknown == 0 -> "✅"
        passing == judged and path > 0 -> "◌"
        true -> "❌"
      end

    [
      "#{icon} #{passing}/#{judged}",
      if(path > 0, do: "#{path} ◌"),
      if(unknown > 0, do: "#{unknown} ❔")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp marker(by_id, case_id, path) do
    case Map.get(by_id, "policy.#{case_id}.#{path}") do
      nil -> "–"
      %{classification: :works} -> "✅"
      %{classification: :setup_failed} -> "❔"
      %{blocked_by: [_ | _]} -> "◌"
      _row -> "❌"
    end
  end
end
