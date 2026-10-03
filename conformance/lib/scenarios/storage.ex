# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Storage do
  @moduledoc """
  Tier 1: each type's values round-trip through create, a fresh read, update
  and update to nil, one cell per type and value class. See
  `Ash.Conformance.Storage`.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Storage

  def all do
    for type <- Storage.types(), class <- Storage.cells(type) do
      name = type.name
      run = fn ctx -> Storage.round_trip(ctx.adapter, name, class) end

      opts = [
        fixture: :empty,
        semantic_basis: "../lib/ash/type/type.ex",
        detail: fn adapter, outcome -> Storage.detail(adapter, name, outcome) end
      ]

      new("storage.#{name}.#{class}", :storage, Storage.expected(class), run, opts)
    end
  end
end
