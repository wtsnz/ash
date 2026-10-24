# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.ExpressionsTest do
  @moduledoc """
  The hand-written expression answers agree with Ash's own in-memory
  evaluation, run through the ETS data layer, so a difference between the
  guide and Ash's evaluator is a recorded decision rather than a hidden one.
  """
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Catalog, Probe, Report}

  @scenarios Catalog.all()
             |> Enum.filter(&String.starts_with?(&1.id, ["expr.", "nil."]))
             |> Enum.map(& &1.id)

  for id <- @scenarios do
    test "Ash's evaluation agrees with #{id}" do
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(id)))
      report = Probe.run(scenario, Ash.Conformance.Ets)

      case {scenario.id, scenario.expected} do
        # SQL keeps no row; Ash's evaluator says `-7 in [7, nil]` is false.
        {"nil.not_in_with_nil", :unresolved} -> assert report.observation.actual == "[2, 4]"
        # Ash's evaluator returns true for `nil or true`, like SQL.
        {"nil.or", :unresolved} -> assert report.observation.actual == "[1, 3]"
        # Ash's evaluator gets nil-left `and`/`or` wrong (`runtime-nil-logic`).
        {"nil.not_and_false", _} -> assert report.observation.actual == "[1, 2, 4]"
        {"nil.not_or_false", _} -> assert report.observation.actual == "[2, 3]"
        # Ash simplifies the filter to `true` first (`in-simplification`).
        {"nil.not_contradictory_in", _} -> assert report.observation.actual == "[1, 2, 3, 4]"
        {_id, expected} -> assert report.observation.actual == Report.value(expected)
      end
    end
  end
end
