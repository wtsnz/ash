# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Combinations do
  @moduledoc """
  The combination grid: a base case, one case per feature alone, and
  pairwise cases that combine features. Each pairwise case requires the
  cases for its features alone. See `Ash.Conformance.Combinations`.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Combinations

  @basis "../documentation/topics/resources/aggregates.md"

  def all do
    for test_case <- Combinations.cases() do
      run = fn ctx -> Combinations.run(ctx.adapter, test_case) end
      expected = Combinations.reference(test_case)

      opts = [
        fixture: :combination,
        requires: Combinations.requires(test_case),
        description: inspect(test_case),
        semantic_basis: @basis
      ]

      new("#{Combinations.scenario_id(test_case)}", :combinations, expected, run, opts)
    end
  end
end
