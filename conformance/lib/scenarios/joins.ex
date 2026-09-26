# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Joins do
  @moduledoc """
  Reads that filter through to-many relationships, calculations used as
  inputs, and writes, on the combination tables (`:joins` fixture, which
  every data layer runs):

  | item | owner | value | status |
  | --- | --- | --- | --- |
  | 11 | 1 | 5 | open |
  | 12 | 1 | 3 | closed |
  | 13 | 1 | nil | open |
  | 14 | 1 | 1 | closed |
  | 15 | 1 | 6 | open |
  | 21 | 2 | 4 | open |
  | 22 | 2 | 7 | open |
  | 23 | 2 | 2 | closed |

  Owner 3 has no items. Links: owner 1 to 21 and 22, owner 2 to 11, 13 and
  15, owner 3 to 12.

  A filter through a to-many relationship talks about one owner joined to
  one related row at a time (the expressions guide, "Filter semantics &
  joins"): each owner appears once, however many rows match, and two
  conditions on the same relationship must hold for the same related row.
  """
  require Ash.Expr
  require Ash.Query
  import Ash.Expr, only: [expr: 1]
  import Ash.Conformance.Scenario, only: [new: 5]

  @reads "../documentation/topics/reference/expressions.md"
  @calculations "../documentation/topics/resources/calculations.md"
  @relationships "../documentation/topics/resources/relationships.md"
  @creates "../lib/ash.ex"

  def all, do: reads() ++ calculations() ++ writes()

  defp reads do
    [
      new("read.join_to_many", :reads, [1, 2], &owners(&1, expr(items.value > 4)), opts(@reads)),
      new(
        "read.join_or_paths",
        :reads,
        [1, 2],
        &owners(&1, expr(items.status == "closed" or linked_items.value > 5)),
        opts(@reads)
      ),
      # Both conditions must hold for the same item: none is closed and above 4.
      new(
        "read.join_same_row",
        :reads,
        [],
        &owners(&1, expr(items.value > 4 and items.status == "closed")),
        opts(@reads)
      ),
      new(
        "read.join_exists_or",
        :reads,
        [1, 2, 3],
        &owners(&1, expr(exists(items, value > 5) or exists(linked_items, status == "closed"))),
        opts(@reads)
      ),
      # Owners with an item whose value is not above 4; owner 3 has none.
      new(
        "read.join_negated",
        :reads,
        [1, 2],
        &owners(&1, expr(not (items.value > 4))),
        opts(@reads)
      ),
      new(
        "read.join_count",
        :reads,
        2,
        fn ctx ->
          ctx.adapter.resource(:combo_owner)
          |> Ash.Query.filter(items.value > 0)
          |> Ash.count!(authorize?: false)
        end,
        opts(@reads)
      ),
      new(
        "read.join_many_to_many_count",
        :reads,
        2,
        fn ctx ->
          ctx.adapter.resource(:combo_owner)
          |> Ash.Query.filter(linked_items.status == "open")
          |> Ash.count!(authorize?: false)
        end,
        opts(@reads)
      ),
      new(
        "read.join_limit",
        :reads,
        [1, 2],
        fn ctx ->
          ctx.adapter.resource(:combo_owner)
          |> Ash.Query.filter(items.value > 0)
          |> Ash.Query.sort(:id)
          |> Ash.Query.limit(2)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        opts(@reads)
      ),
      new(
        "read.join_page",
        :reads,
        {[2], 3},
        fn ctx ->
          page =
            ctx.adapter.resource(:combo_owner)
            |> Ash.Query.for_read(:paged)
            |> Ash.Query.filter(linked_items.value > 0)
            |> Ash.Query.sort(:id)
            |> Ash.read!(authorize?: false, page: [limit: 1, offset: 1, count: true])

          {Enum.map(page.results, & &1.id), page.count}
        end,
        opts(@reads)
      ),
      new(
        "read.sort_to_one",
        :ordering,
        [21, 22, 23, 11, 12, 13, 14, 15],
        fn ctx ->
          ctx.adapter.resource(:combo_item)
          |> Ash.Query.sort([{"owner.label", :desc}, {:id, :asc}])
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        opts(@reads)
      )
    ]
  end

  defp calculations do
    [
      # Doubled values, nils skipped: owner 1 has 10 + 6 + 2 + 12.
      new(
        "calc.aggregate_over_calculation",
        :calculations,
        %{1 => 30, 2 => 26, 3 => nil},
        &owner_field(&1, :double_sum),
        opts(@calculations)
      ),
      new(
        "calc.over_aggregate",
        :calculations,
        %{1 => 10, 2 => 6, 3 => 0},
        &owner_field(&1, :count_doubled),
        opts(@calculations)
      ),
      new(
        "calc.filter_over_aggregate",
        :calculations,
        [1],
        &owners(&1, expr(count_doubled > 8)),
        opts(@calculations)
      ),
      new(
        "calc.argument_filter",
        :calculations,
        [11, 15, 22],
        fn ctx ->
          ctx.adapter.resource(:combo_item)
          |> Ash.Query.filter(value_plus(amount: 10) > 14)
          |> Ash.Query.sort(:id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        opts(@calculations)
      ),
      new(
        "calc.argument_sort",
        :calculations,
        [22, 15, 11, 21, 12, 23, 14, 13],
        fn ctx ->
          ctx.adapter.resource(:combo_item)
          |> Ash.Query.sort([{:value_plus, {%{amount: 1}, :desc_nils_last}}, {:id, :asc}])
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        opts(@calculations)
      )
    ]
  end

  defp writes do
    [
      new(
        "write.atomic_expression",
        :writes,
        {11, 11},
        fn ctx ->
          item = ctx.adapter.resource(:combo_item)
          record = Ash.get!(item, 11, authorize?: false)

          updated =
            record
            |> Ash.Changeset.for_update(:update, %{}, authorize?: false)
            |> Ash.Changeset.atomic_update(:value, expr(value * 2 + 1))
            |> Ash.update!(authorize?: false)

          {updated.value, Ash.get!(item, 11, authorize?: false).value}
        end,
        opts(@reads)
      ),
      # The top two by value are 22 (7) and 15 (6).
      new(
        "write.bulk_update_sorted_limit",
        :writes,
        [15, 22],
        fn ctx ->
          item = ctx.adapter.resource(:combo_item)

          item
          |> Ash.Query.sort(value: :desc_nils_last, id: :asc)
          |> Ash.Query.limit(2)
          |> Ash.bulk_update!(:update, %{status: "top"}, authorize?: false, return_errors?: true)

          item
          |> Ash.Query.filter(status == "top")
          |> Ash.Query.sort(:id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        opts(@reads)
      ),
      # The two lowest values, 14 (1) and 23 (2), are destroyed.
      new(
        "write.bulk_destroy_sorted_limit",
        :writes,
        [11, 12, 13, 15, 21, 22],
        fn ctx ->
          item = ctx.adapter.resource(:combo_item)

          item
          |> Ash.Query.sort(value: :asc_nils_last, id: :asc)
          |> Ash.Query.limit(2)
          |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false, return_errors?: true)

          item |> Ash.Query.sort(:id) |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
        end,
        opts(@reads)
      ),
      # `sorted?: true` returns records in input order (`Ash.bulk_create/4`).
      new(
        "write.bulk_create_sorted",
        :writes,
        [33, 31, 32],
        fn ctx ->
          inputs = for id <- [33, 31, 32], do: %{id: id, owner_id: 3, value: id, status: "open"}

          %{records: records} =
            Ash.bulk_create!(inputs, ctx.adapter.resource(:combo_item), :create,
              return_records?: true,
              sorted?: true,
              authorize?: false
            )

          Enum.map(records, & &1.id)
        end,
        opts(@creates)
      ),
      new(
        "write.manage_create",
        :writes,
        [41, 42],
        fn ctx ->
          items = [%{id: 41, value: 1, status: "open"}, %{id: 42, value: 2, status: "open"}]
          input = %{id: 4, label: "owner-4", items: items}

          ctx.adapter.resource(:combo_owner)
          |> Ash.Changeset.for_create(:create_with_items, input, authorize?: false)
          |> Ash.create!(authorize?: false)

          item_ids(ctx, 4)
        end,
        opts(@relationships)
      ),
      # Direct control keeps 11, creates 16 and destroys owner 1's other items.
      new(
        "write.manage_direct_control",
        :writes,
        {[11, 16], 5},
        fn ctx ->
          owner = ctx.adapter.resource(:combo_owner)
          items = [%{id: 11}, %{id: 16, value: 9, status: "open"}]

          owner
          |> Ash.get!(1, authorize?: false)
          |> Ash.Changeset.for_update(:replace_items, %{items: items}, authorize?: false)
          |> Ash.update!(authorize?: false)

          {item_ids(ctx, 1), Ash.count!(ctx.adapter.resource(:combo_item), authorize?: false)}
        end,
        opts(@relationships)
      )
    ]
  end

  defp owners(ctx, expression) do
    ctx.adapter.resource(:combo_owner)
    |> Ash.Query.do_filter(expression)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp owner_field(ctx, field) do
    ctx.adapter.resource(:combo_owner)
    |> Ash.Query.load(field)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, Map.fetch!(&1, field)})
  end

  defp item_ids(ctx, owner_id) do
    ctx.adapter.resource(:combo_item)
    |> Ash.Query.filter(owner_id == ^owner_id)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp opts(basis), do: [fixture: :joins, semantic_basis: basis]
end
