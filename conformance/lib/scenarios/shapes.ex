# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Shapes do
  @moduledoc """
  The shapes grid: every combination of key type, path depth, condition,
  aggregate kind and use, and related calculations over missing rows. See
  `Ash.Conformance.Shapes`.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Shapes

  @aggregates "../documentation/topics/resources/aggregates.md"
  @calculations "../documentation/topics/resources/calculations.md"

  def all, do: grid() ++ related() ++ sorted()

  def ids, do: Enum.map(all(), & &1.id)

  defp grid do
    for test_case <- Shapes.cases() do
      run = fn ctx -> Shapes.run(ctx.adapter, test_case) end
      expected = Shapes.reference(test_case)
      opts = [fixture: :shapes, requires: Shapes.requires(test_case), semantic_basis: @aggregates]
      new("#{Shapes.scenario_id(test_case)}", :shapes, expected, run, opts)
    end
  end

  # A sort by the destination's aggregate, inside the path's subquery.
  defp sorted do
    for sorted_case <- Shapes.sorted_cases() do
      run = fn ctx -> Shapes.sorted_run(ctx.adapter, sorted_case) end
      expected = Shapes.sorted_reference(sorted_case)
      opts = [fixture: :shapes, semantic_basis: @aggregates]
      new("#{Shapes.sorted_id(sorted_case)}", :shapes, expected, run, opts)
    end
  end

  # A calculation over a related field keeps the rows whose related row is missing.
  defp related do
    for related_case <- Shapes.related_cases() do
      run = fn ctx -> Shapes.related_run(ctx.adapter, related_case) end
      expected = Shapes.related_reference(related_case)
      opts = [fixture: :shapes, semantic_basis: @calculations]
      new("#{Shapes.related_id(related_case)}", :shapes, expected, run, opts)
    end
  end
end
