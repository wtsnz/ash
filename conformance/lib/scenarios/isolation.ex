# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Isolation do
  @moduledoc "Tenant and actor isolation, with explicit static reference answers."
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query
  require Ash.Expr

  @tenancy [
    fixture: :isolation,
    semantic_basis: "../documentation/topics/advanced/multitenancy.md"
  ]
  @policy [fixture: :isolation, semantic_basis: "../test/policy/context_shared_test.exs"]

  def all, do: tenancy() ++ authorization() ++ equivalences() ++ writes()

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
          {:error, error} = Ash.read(ctx.adapter.resource(:tenant_parent), tenant: "invalid")
          {error.__struct__, Enum.map(error.errors, &{&1.__struct__, &1.value})}
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

  defp authorization do
    [
      new(
        "auth.read",
        :authorization,
        {[1, 2], [3]},
        fn ctx ->
          {ids(authorized(ctx, :secure_parent, 1)), ids(authorized(ctx, :secure_parent, 2))}
        end,
        @policy
      ),
      new(
        "auth.children",
        :authorization,
        {[1, 2, 4], [3, 5]},
        fn ctx ->
          {ids(authorized(ctx, :secure_item, 1)), ids(authorized(ctx, :secure_item, 2))}
        end,
        @policy
      ),
      new(
        "auth.relationship_load",
        :authorization,
        %{1 => [1001, 1002], 2 => [1004]},
        fn ctx ->
          relationships(authorized(ctx, :secure_parent, 1), :items)
        end,
        @policy
      ),
      new(
        "auth.loaded_aggregates",
        :authorization,
        {%{1 => {2, 5}, 2 => {1, 8}}, %{3 => {1, 50}}},
        fn ctx ->
          {totals(authorized(ctx, :secure_parent, 1)), totals(authorized(ctx, :secure_parent, 2))}
        end,
        @policy
      ),
      new(
        "auth.root_aggregates",
        :authorization,
        {%{count: 3, sum: 13}, %{count: 2, sum: 149}},
        fn ctx ->
          {root(authorized(ctx, :secure_item, 1)), root(authorized(ctx, :secure_item, 2))}
        end,
        @policy
      ),
      new(
        "auth.aggregate_filter",
        :authorization,
        [2],
        fn ctx ->
          authorized(ctx, :secure_parent, 1) |> Ash.Query.filter(item_sum > 6) |> ids()
        end,
        @policy
      ),
      new(
        "auth.aggregate_sort",
        :authorization,
        [2, 1],
        fn ctx ->
          authorized(ctx, :secure_parent, 1)
          |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
          |> ids(false)
        end,
        @policy
      ),
      new(
        "auth.offset_page",
        :authorization,
        {[2], 2, true},
        fn ctx ->
          authorized(ctx, :secure_parent, 1)
          |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
          |> Ash.Query.for_read(:offset_page)
          |> Ash.read!(page: [limit: 1, count: true])
          |> page_result()
        end,
        @policy
      ),
      new(
        "auth.keyset_pages",
        :authorization,
        {[2, 1], [2, 2]},
        fn ctx ->
          authorized(ctx, :secure_parent, 1)
          |> Ash.Query.sort(item_sum: :desc, local_id: :asc)
          |> Ash.Query.for_read(:keyset_page)
          |> keyset_pages()
        end,
        @policy
      ),
      new(
        "auth.bounds",
        :authorization,
        {%{1 => [1002], 2 => [1004]}, %{1 => [1001], 2 => []}},
        fn ctx ->
          q = authorized(ctx, :secure_parent, 1)
          {relationships(q, :top_items), relationships(q, :middle_items)}
        end,
        @policy
      ),
      new(
        "auth.from_many",
        :authorization,
        %{1 => [1002], 2 => [1004]},
        fn ctx ->
          relationships(authorized(ctx, :secure_parent, 1), :best_item)
        end,
        @policy
      ),
      new(
        "auth.tenant_interaction",
        :authorization,
        {%{1 => {2, 5}, 2 => {1, 8}}, %{1 => {1, 700}, 3 => {1, 1000}}},
        fn ctx ->
          {totals(authorized(ctx, :secure_parent, 1)),
           totals(authorized(ctx, :secure_parent, 1, 2))}
        end,
        @policy
      ),
      new(
        "auth.context_read",
        :authorization,
        [1, 4],
        fn ctx ->
          contextual(ctx, :context_item) |> ids()
        end,
        @policy
      ),
      new(
        "auth.context_relationship",
        :authorization,
        %{1 => [1001], 2 => [1004]},
        fn ctx ->
          contextual(ctx, :context_parent) |> relationships(:items)
        end,
        @policy
      ),
      new(
        "auth.context_aggregates",
        :authorization,
        %{1 => {1, 2}, 2 => {1, 8}},
        fn ctx ->
          contextual(ctx, :context_parent) |> totals()
        end,
        @policy
      ),
      new(
        "auth.context_root",
        :authorization,
        %{count: 2, sum: 10},
        fn ctx ->
          contextual(ctx, :context_item) |> root()
        end,
        @policy
      )
    ]
  end

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
            Ash.Conformance.IsolationFixtures.items()
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
    ] ++ authorized_writes()
  end

  # Actor 1 owns tenant 1's items 1, 2 and 4; actor 2 owns 3 and 5. With the
  # default `authorize_with: :filter`, bulk writes skip rows the actor cannot
  # change instead of failing.
  defp authorized_writes do
    unchanged = [{1, 700}, {2, 600}, {3, 900}, {4, 1000}]

    [
      new(
        "auth.write_bulk_update_atomic",
        :writes,
        {[{1, 0}, {2, 0}, {3, 99}, {4, 0}, {5, 50}], unchanged},
        fn ctx ->
          authorized(ctx, :secure_item, 1)
          |> Ash.bulk_update!(:update, %{value: 0},
            strategy: :atomic,
            actor: %{id: 1},
            tenant: 1,
            authorize?: true
          )

          {values(ctx, :secure_item, 1), values(ctx, :secure_item, 2)}
        end,
        @policy
      ),
      new(
        "auth.write_bulk_update_stream",
        :writes,
        {[{1, 3}, {2, 4}, {3, 99}, {4, 9}, {5, 50}], unchanged},
        fn ctx ->
          authorized(ctx, :secure_item, 1)
          |> Ash.bulk_update!(:update, %{},
            atomic_update: %{value: Ash.Expr.expr(value + 1)},
            strategy: :stream,
            actor: %{id: 1},
            tenant: 1,
            authorize?: true
          )

          {values(ctx, :secure_item, 1), values(ctx, :secure_item, 2)}
        end,
        @policy
      ),
      new(
        "auth.write_bulk_destroy",
        :writes,
        {[{3, 99}, {5, 50}], unchanged},
        fn ctx ->
          authorized(ctx, :secure_item, 1)
          |> Ash.bulk_destroy!(:destroy, %{},
            strategy: :atomic,
            actor: %{id: 1},
            tenant: 1,
            authorize?: true
          )

          {values(ctx, :secure_item, 1), values(ctx, :secure_item, 2)}
        end,
        @policy
      ),
      new(
        "auth.write_forbidden",
        :writes,
        {Ash.Error.Forbidden, 99},
        fn ctx ->
          item =
            Ash.get!(ctx.adapter.resource(:secure_item), [local_id: 3],
              tenant: 1,
              authorize?: false
            )

          result =
            item
            |> Ash.Changeset.for_update(:update, %{value: 0}, actor: %{id: 1}, tenant: 1)
            |> Ash.update(authorize?: true)

          {elem(result, 1).__struct__, hd(values(ctx, :secure_item, 1, [3])) |> elem(1)}
        end,
        @policy
      )
    ]
  end

  defp values(ctx, role, tenant, local_ids \\ nil) do
    query(ctx, role, tenant)
    |> then(fn query ->
      if local_ids, do: Ash.Query.filter(query, local_id in ^local_ids), else: query
    end)
    |> Ash.Query.sort(:local_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.local_id, &1.value})
  end

  def query(ctx, role, tenant), do: ctx.adapter.resource(role) |> Ash.Query.set_tenant(tenant)

  def authorized(ctx, role, actor, tenant \\ 1) do
    query(ctx, role, tenant)
    |> Ash.Query.for_read(:read, %{}, actor: %{id: actor}, authorize?: true)
  end

  defp contextual(ctx, role) do
    authorized(ctx, role, 1) |> Ash.Query.set_context(%{shared: %{department: 1}})
  end

  def ids(query, sort? \\ true) do
    query = if sort?, do: Ash.Query.sort(query, :local_id), else: query
    query |> Ash.read!() |> Enum.map(& &1.local_id)
  end

  def relationships(query, name) do
    query
    |> Ash.Query.load(name)
    |> Ash.read!()
    |> unique_map(fn row ->
      {row.local_id, row |> Map.fetch!(name) |> List.wrap() |> Enum.map(& &1.id)}
    end)
  end

  def totals(query) do
    query
    |> Ash.Query.load([:item_count, :item_sum])
    |> Ash.read!()
    |> unique_map(&{&1.local_id, {&1.item_count, &1.item_sum}})
  end

  # Local IDs repeat across tenants. A row leaked from another tenant would
  # silently replace its namesake in a map, so a repeated key raises instead.
  defp unique_map(rows, pair) do
    Enum.reduce(rows, %{}, fn row, acc ->
      {key, value} = pair.(row)

      if Map.has_key?(acc, key),
        do: raise("local ID #{inspect(key)} appears twice; a row leaked from another tenant")

      Map.put(acc, key, value)
    end)
  end

  def root(query), do: Ash.aggregate!(query, [{:count, :count}, {:sum, :sum, field: :value}])
  def page_result(page), do: {Enum.map(page.results, & &1.local_id), page.count, page.more?}

  def keyset_pages(query, after_key \\ nil, ids \\ [], counts \\ []) do
    page_opts = [limit: 1, count: true] ++ if(after_key, do: [after: after_key], else: [])
    page = Ash.read!(query, page: page_opts)
    ids = ids ++ Enum.map(page.results, & &1.local_id)
    counts = counts ++ [page.count]

    if page.more? do
      keyset_pages(query, List.last(page.results).__metadata__.keyset, ids, counts)
    else
      {ids, counts}
    end
  end
end
