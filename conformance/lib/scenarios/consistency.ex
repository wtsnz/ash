# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Consistency do
  @moduledoc "Independent checks: counts against loads, and root sums against an in-memory reference."
  import Ash.Conformance.Scenario, only: [new: 5]
  import Ash.Conformance.Scenarios.IsolationHelpers
  require Ash.Query
  require Ash.Expr

  @tenancy [
    fixture: :isolation,
    semantic_basis: "../documentation/topics/advanced/multitenancy.md"
  ]
  @policy [fixture: :isolation, semantic_basis: "../test/policy/context_shared_test.exs"]

  def all, do: equivalences()

  defp equivalences do
    [
      new(
        "equivalence.visible_count_load",
        :equivalence,
        [{1, 2, 2}, {2, 1, 1}],
        fn ctx ->
          # Preconditions: no bounds, unique destination identities, same tenant/actor.
          authorized(ctx, :secure_parent, 1)
          |> Ash.Query.load([:items, :item_count])
          |> Ash.Query.sort(:local_id)
          |> Ash.read!()
          |> Enum.map(&{&1.local_id, &1.item_count, length(&1.items)})
        end,
        @policy
      ),
      new(
        "equivalence.root_reference",
        :equivalence,
        {13, 13},
        fn ctx ->
          # This oracle scans literal fixture maps; it does not plan a query.
          reference =
            Ash.Conformance.Fixtures.Isolation.items()
            |> Enum.filter(&(&1.tenant_id == 1 and &1.owner_id == 1))
            |> Enum.map(& &1.value)
            |> Enum.sum()

          {Ash.sum!(authorized(ctx, :secure_item, 1), :value), reference}
        end,
        @policy
      ),
      new(
        "read.selection_expression",
        :reads,
        [{1, 2, true}, {2, 4, true}],
        fn ctx ->
          query(ctx, :tenant_parent, 1)
          |> Ash.Query.filter(local_id < 3)
          |> Ash.Query.select([:local_id])
          |> Ash.Query.load(:double_local_id)
          |> Ash.Query.sort(:local_id)
          |> Ash.read!()
          |> Enum.map(&{&1.local_id, &1.double_local_id, match?(%Ash.NotLoaded{}, &1.name)})
        end,
        @tenancy
      )
    ]
  end
end
