# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Tenancy do
  @moduledoc "Attribute tenancy: two tenants with overlapping local identities."
  import Ash.Conformance.Scenario, only: [new: 5]
  import Ash.Conformance.Scenarios.IsolationHelpers
  require Ash.Query
  require Ash.Expr

  @tenancy [
    fixture: :isolation,
    semantic_basis: "../documentation/topics/advanced/multitenancy.md"
  ]

  def all, do: tenancy() ++ writes()

  defp tenancy do
    [
      new(
        "tenant.read",
        :tenancy,
        {[1, 2, 3], [1, 2, 3]},
        fn ctx ->
          {ids(query(ctx, :tenant_parent, 1)), ids(query(ctx, :tenant_parent, 2))}
        end,
        @tenancy
      ),
      new(
        "tenant.identities",
        :tenancy,
        {101, 201},
        fn ctx ->
          {Ash.get!(ctx.adapter.resource(:tenant_parent), [local_id: 1], tenant: 1).id,
           Ash.get!(ctx.adapter.resource(:tenant_parent), [local_id: 1], tenant: 2).id}
        end,
        @tenancy
      ),
      new(
        "tenant.relationship_load",
        :tenancy,
        {%{1 => [1001, 1002, 1003], 2 => [1004], 3 => [1005]},
         %{1 => [2001, 2002], 2 => [2003], 3 => [2004]}},
        fn ctx ->
          {relationships(query(ctx, :tenant_parent, 1), :items),
           relationships(query(ctx, :tenant_parent, 2), :items)}
        end,
        @tenancy
      ),
      new(
        "tenant.relationship_filter",
        :tenancy,
        {[1, 3], []},
        fn ctx ->
          for tenant <- [1, 2] do
            query(ctx, :tenant_parent, tenant)
            |> Ash.Query.filter(items.value < 100 and items.value > 40)
            |> ids()
          end
          |> List.to_tuple()
        end,
        @tenancy
      ),
      new(
        "tenant.loaded_aggregates",
        :tenancy,
        {%{1 => {3, 104}, 2 => {1, 8}, 3 => {1, 50}},
         %{1 => {2, 1300}, 2 => {1, 900}, 3 => {1, 1000}}},
        fn ctx ->
          {totals(query(ctx, :tenant_parent, 1)), totals(query(ctx, :tenant_parent, 2))}
        end,
        @tenancy ++ [benchmark: true]
      ),
      new(
        "tenant.root_aggregates",
        :tenancy,
        {%{count: 5, sum: 162}, %{count: 4, sum: 3200}},
        fn ctx ->
          {root(query(ctx, :tenant_item, 1)), root(query(ctx, :tenant_item, 2))}
        end,
        @tenancy
      ),
      new(
        "tenant.aggregate_filter_sort",
        :tenancy,
        {[1, 3], [1, 3, 2]},
        fn ctx ->
          for tenant <- [1, 2] do
            query(ctx, :tenant_parent, tenant)
            |> Ash.Query.filter(item_sum > 40)
            |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
            |> ids(false)
          end
          |> List.to_tuple()
        end,
        @tenancy
      ),
      new(
        "tenant.aggregate_offset_page",
        :tenancy,
        {[3], 2, false},
        fn ctx ->
          query(ctx, :tenant_parent, 1)
          |> Ash.Query.filter(item_sum > 40)
          |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
          |> Ash.Query.for_read(:offset_page)
          |> Ash.read!(page: [limit: 1, offset: 1, count: true])
          |> page_result()
        end,
        @tenancy
      ),
      new(
        "tenant.aggregate_keyset_pages",
        :tenancy,
        {[1, 3, 2], [3, 3, 3]},
        fn ctx ->
          query(ctx, :tenant_parent, 1)
          |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
          |> Ash.Query.for_read(:keyset_page)
          |> keyset_pages()
        end,
        @tenancy
      ),
      new(
        "tenant.missing",
        :tenancy,
        {:error, Ash.Error.Invalid, ~r/require a tenant to be specified/},
        fn ctx ->
          Ash.read!(ctx.adapter.resource(:tenant_parent))
        end,
        @tenancy
      ),
      new(
        "tenant.invalid",
        :tenancy,
        {Ash.Error.Invalid, [{Ash.Error.Query.InvalidFilterValue, "invalid"}]},
        fn ctx ->
          case Ash.read(ctx.adapter.resource(:tenant_parent), tenant: "invalid") do
            {:error, error} ->
              {error.__struct__, Enum.map(error.errors, &{&1.__struct__, &1.value})}

            {:ok, records} ->
              {:accepted, Enum.map(records, & &1.local_id)}
          end
        end,
        @tenancy
      ),
      new(
        "tenant.unknown",
        :tenancy,
        [],
        fn ctx ->
          query(ctx, :tenant_parent, 99) |> ids()
        end,
        @tenancy
      ),
      new(
        "tenant.explicit_global",
        :tenancy,
        [101, 102, 103, 201, 202, 203],
        fn ctx ->
          ctx.adapter.resource(:tenant_parent)
          |> Ash.Query.for_read(:global)
          |> Ash.Query.sort(:id)
          |> Ash.read!()
          |> Enum.map(& &1.id)
        end,
        @tenancy
      ),
      new(
        "tenant.bounds",
        :relationships,
        {%{1 => [1003], 2 => [1004], 3 => [1005]}, %{1 => [1002], 2 => [], 3 => []}},
        fn ctx ->
          q = query(ctx, :tenant_parent, 1)
          {relationships(q, :top_items), relationships(q, :middle_items)}
        end,
        @tenancy
      ),
      new(
        "tenant.from_many",
        :relationships,
        %{1 => [1003], 2 => [1004], 3 => [1005]},
        fn ctx ->
          relationships(query(ctx, :tenant_parent, 1), :best_item)
        end,
        @tenancy
      )
    ]
  end

  defp writes do
    [
      new(
        "write.lifecycle",
        :writes,
        {1, 21, []},
        fn ctx ->
          resource = ctx.adapter.resource(:tenant_parent)
          attributes = %{id: 104, local_id: 4, owner_id: 1, name: "created"}

          created =
            resource
            |> Ash.Changeset.for_create(:create, attributes, tenant: 1)
            |> Ash.create!()

          updated = created |> Ash.Changeset.for_update(:update, %{owner_id: 21}) |> Ash.update!()
          Ash.destroy!(updated)

          {created.tenant_id, updated.owner_id,
           query(ctx, :tenant_parent, 1) |> Ash.Query.filter(local_id == 4) |> ids()}
        end,
        @tenancy
      ),
      # Updating by the tenant-scoped identity must touch only that tenant.
      new(
        "tenant.write_local_identity",
        :writes,
        {[{1, 2}], [{1, 5}]},
        fn ctx ->
          item = ctx.adapter.resource(:tenant_item)

          item
          |> Ash.get!([local_id: 1], tenant: 2)
          |> Ash.Changeset.for_update(:update, %{value: 5})
          |> Ash.update!()

          {values(ctx, :tenant_item, 1, [1]), values(ctx, :tenant_item, 2, [1])}
        end,
        @tenancy
      ),
      new(
        "tenant.write_bulk_destroy",
        :writes,
        {[1, 2, 3, 4, 5], [2, 3, 4]},
        fn ctx ->
          query(ctx, :tenant_item, 2)
          |> Ash.Query.filter(local_id == 1)
          |> Ash.bulk_destroy!(:destroy, %{}, strategy: :stream, tenant: 2)

          {ids(query(ctx, :tenant_item, 1)), ids(query(ctx, :tenant_item, 2))}
        end,
        @tenancy
      )
    ]
  end
end
