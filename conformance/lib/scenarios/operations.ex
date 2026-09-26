# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Operations do
  @moduledoc """
  Tier 2: each filter, sort and aggregate on each type it applies to, with
  integers as the control. See `Ash.Conformance.Operations`.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.{Operations, Storage}

  def all do
    for type <- Storage.types(),
        operation <- Operations.operations(),
        Operations.applies?(operation, type.name) do
      name = type.name
      run = fn ctx -> Operations.run(ctx.adapter, name, operation) end
      expected = Operations.expected(name, operation)

      opts = [
        fixture: {:operations, name},
        requires: Operations.requires(name, operation),
        semantic_basis: "../documentation/topics/reference/expressions.md"
      ]

      new("ops.#{name}.#{operation}", :operations, expected, run, opts)
    end
  end
end
