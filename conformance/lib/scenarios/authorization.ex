# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Authorization do
  @moduledoc "Actor and shared-context policies on reads, loads, aggregates, pages and writes."
  import Ash.Conformance.Scenario, only: [new: 5]
  import Ash.Conformance.Scenarios.IsolationHelpers
  require Ash.Query
  require Ash.Expr

  @policy [fixture: :isolation, semantic_basis: "../test/policy/context_shared_test.exs"]

  def all, do: authorization() ++ authorized_writes()

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
end
