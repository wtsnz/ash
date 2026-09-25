# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Schema do
  @moduledoc "The same record identities live in two separately provisioned storage contexts."
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query

  @opts [
    profile: :context_tenancy,
    fixture: :context_tenancy,
    semantic_basis: "../documentation/topics/advanced/multitenancy.md",
    capabilities: [schema_parent: :multitenancy]
  ]

  def all do
    [
      new(
        "schema.direct",
        :tenancy,
        {[2, 3], [70, 90]},
        fn ctx ->
          for tenant <- ["dc_tenant_a", "dc_tenant_b"] do
            ctx.adapter.resource(:schema_item)
            |> Ash.Query.sort(:id)
            |> Ash.read!(tenant: tenant)
            |> Enum.map(& &1.value)
          end
          |> List.to_tuple()
        end,
        @opts
      ),
      new(
        "schema.relationships",
        :tenancy,
        {[[2, 3], []], [[70], [90]]},
        fn ctx ->
          for tenant <- ["dc_tenant_a", "dc_tenant_b"] do
            ctx.adapter.resource(:schema_parent)
            |> Ash.Query.load(:items)
            |> Ash.Query.sort(:id)
            |> Ash.read!(tenant: tenant)
            |> Enum.map(fn row -> Enum.map(row.items, & &1.value) end)
          end
          |> List.to_tuple()
        end,
        @opts
      ),
      new(
        "schema.loaded_aggregates",
        :tenancy,
        {[{2, 5}, {0, 0}], [{1, 70}, {1, 90}]},
        fn ctx ->
          for tenant <- ["dc_tenant_a", "dc_tenant_b"] do
            ctx.adapter.resource(:schema_parent)
            |> Ash.Query.load([:item_count, :item_sum])
            |> Ash.Query.sort(:id)
            |> Ash.read!(tenant: tenant)
            |> Enum.map(&{&1.item_count, &1.item_sum})
          end
          |> List.to_tuple()
        end,
        @opts
      ),
      new(
        "schema.root_aggregate",
        :tenancy,
        {5, 160},
        fn ctx ->
          {Ash.sum!(ctx.adapter.resource(:schema_item), :value, tenant: "dc_tenant_a"),
           Ash.sum!(ctx.adapter.resource(:schema_item), :value, tenant: "dc_tenant_b")}
        end,
        @opts
      ),
      new(
        "schema.filtered_page",
        :tenancy,
        {[1], 1},
        fn ctx ->
          page =
            ctx.adapter.resource(:schema_parent)
            |> Ash.Query.for_read(:paged)
            |> Ash.Query.filter(item_sum > 0)
            |> Ash.Query.sort(item_sum: :desc, id: :asc)
            |> Ash.read!(tenant: "dc_tenant_a", page: [limit: 1, count: true])

          {Enum.map(page.results, & &1.id), page.count}
        end,
        @opts
      )
    ]
  end
end
