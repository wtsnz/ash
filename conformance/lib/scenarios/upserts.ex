# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Upserts do
  @moduledoc """
  Upserts and bulk writes against tenant-scoped identities.

  Each tenant has items with local IDs 1 to 5 (tenant 1) or 1 to 4 (tenant 2).
  Tenant 1's local ID 1 is record 1001 with value 2; tenant 2's is record 2001
  with value 700. An upsert in one tenant must never read or change the other.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query
  require Ash.Expr

  @opts [fixture: :isolation, semantic_basis: "../documentation/topics/actions/create-actions.md"]
  @bulk [fixture: :isolation, semantic_basis: "../test/actions/bulk/bulk_create_test.exs"]
  @upsert [
    tenant: 1,
    upsert?: true,
    upsert_identity: :local_id,
    upsert_fields: [:value],
    authorize?: false,
    return_records?: true,
    return_errors?: true
  ]

  def all do
    [
      new(
        "upsert.tenant_identity",
        :writes,
        {1001, [{1, 5}, {2, 3}, {3, 99}, {4, 8}, {5, 50}], [{1, 700}]},
        fn ctx ->
          record =
            Ash.create!(
              item(ctx),
              row(9999, 1, 5),
              Keyword.drop(@upsert, [:return_records?, :return_errors?])
            )

          {record.id, values(ctx, 1), values(ctx, 2) |> Enum.take(1)}
        end,
        @opts ++ [capabilities: [tenant_item: :upsert, tenant_item: :multitenancy]]
      ),
      new(
        "upsert.bulk",
        :writes,
        {[{1001, 1, 3}, {9102, 20, 9}], [{1, 3}], [{1, 700}]},
        fn ctx ->
          # The conflicting row brings value 3, so doing nothing on conflict fails.
          result =
            Ash.bulk_create!([row(9101, 1, 3), row(9102, 20, 9)], item(ctx), :create, @upsert)

          {records(result), values(ctx, 1) |> Enum.take(1), values(ctx, 2) |> Enum.take(1)}
        end,
        @bulk ++ [capabilities: [tenant_item: :upsert, tenant_item: :bulk_create]]
      ),
      # The conflicting row keeps value 2, so the condition skips it.
      new(
        "upsert.condition",
        :writes,
        {[{9102, 20, 9}], [{1, 2}]},
        fn ctx ->
          result =
            Ash.bulk_create!(
              [row(9101, 1, 2), row(9102, 20, 9)],
              item(ctx),
              :create,
              @upsert ++ [upsert_condition: Ash.Expr.expr(value != upsert_conflict(:value))]
            )

          {records(result), values(ctx, 1) |> Enum.take(1)}
        end,
        @bulk ++ [capabilities: [tenant_item: :upsert, tenant_item: {:atomic, :upsert}]]
      ),
      new(
        "upsert.skipped_record",
        :writes,
        [{1001, 1, 1, 2, true}],
        fn ctx ->
          Ash.bulk_create!(
            [row(9101, 1, 2)],
            item(ctx),
            :create,
            @upsert ++
              [
                upsert_condition: Ash.Expr.expr(upsert_conflict(:value) > 100),
                return_skipped_upsert?: true
              ]
          ).records
          |> Enum.map(
            &{&1.id, &1.tenant_id, &1.local_id, &1.value, &1.__metadata__[:upsert_skipped]}
          )
        end,
        @bulk ++ [capabilities: [tenant_item: :bulk_upsert_return_skipped]]
      ),
      # Local ID 12 has no owner, which the resource requires.
      new(
        "bulk.partial_success",
        :writes,
        {:partial_success, 1, [10, 11], [10, 11]},
        fn ctx ->
          rows = [
            row(9001, 10, 1),
            Map.delete(row(9002, 11, 2), :value),
            Map.delete(row(9003, 12, 3), :owner_id)
          ]

          result =
            Ash.bulk_create(rows, item(ctx), :create,
              tenant: 1,
              authorize?: false,
              return_records?: true,
              return_errors?: true
            )

          persisted =
            item(ctx)
            |> Ash.Query.set_tenant(1)
            |> Ash.Query.filter(local_id >= 10)
            |> Ash.read!(authorize?: false)
            |> Enum.map(& &1.local_id)
            |> Enum.sort()

          {result.status, result.error_count,
           Enum.map(result.records, & &1.local_id) |> Enum.sort(), persisted}
        end,
        @bulk ++
          [
            capabilities: [
              tenant_item: :bulk_create,
              tenant_item: :bulk_create_with_partial_success
            ]
          ]
      ),
      new(
        "bulk.atomic_increment",
        :writes,
        {[{1, 3}, {2, 4}, {3, 100}, {4, 8}, {5, 50}], [{1, 700}, {2, 600}, {3, 900}, {4, 1000}]},
        fn ctx ->
          item(ctx)
          |> Ash.Query.set_tenant(1)
          |> Ash.Query.filter(parent_key == 1)
          |> Ash.bulk_update!(:update, %{},
            atomic_update: %{value: Ash.Expr.expr(value + 1)},
            strategy: :atomic,
            tenant: 1,
            authorize?: false
          )

          {values(ctx, 1), values(ctx, 2)}
        end,
        [fixture: :isolation, semantic_basis: "../documentation/topics/actions/update-actions.md"] ++
          [capabilities: [tenant_item: :update_query, tenant_item: {:atomic, :update}]]
      )
    ]
  end

  defp item(ctx), do: ctx.adapter.resource(:tenant_item)

  defp row(id, local_id, value),
    do: %{id: id, local_id: local_id, parent_key: 1, owner_id: 1, department: 1, value: value}

  defp records(result),
    do: result.records |> Enum.map(&{&1.id, &1.local_id, &1.value}) |> Enum.sort()

  defp values(ctx, tenant) do
    item(ctx)
    |> Ash.Query.set_tenant(tenant)
    |> Ash.Query.sort(:local_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.local_id, &1.value})
  end
end
