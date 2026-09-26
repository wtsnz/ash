# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Querying do
  @moduledoc """
  Filters, sorting, pagination, calculations and optional query features on the
  `record` and aggregate fixtures. Distinct, combinations and locks are opt-in
  for data layers; Ash rejects them with a documented error when unsupported.
  """
  import Ash.Conformance.Scenario, only: [new: 5, requires: 2]
  import Ash.Conformance.Storage, only: [stored: 1]
  import Ash.Conformance.Scenarios.RecordHelpers
  require Ash.Query
  require Ash.Expr

  @reads "../documentation/topics/actions/read-actions.md"
  @calculations "../documentation/topics/resources/calculations.md"
  @query_docs "../lib/ash/query/query.ex"

  def all, do: filters() ++ sorting() ++ paging() ++ query_features()

  # Nil comparisons are nil and exclude the row, as in SQL.
  defp filters do
    [
      filter("record.filter_equal", [1, 2], Ash.Expr.expr(quantity == 3)),
      filter("record.filter_not_equal", [4, 5, 6], Ash.Expr.expr(quantity != 3)),
      filter("record.filter_range", [1, 2], Ash.Expr.expr(quantity > 0 and quantity < 10)),
      filter("record.filter_in_with_nil", [1, 2], Ash.Expr.expr(quantity in [3, nil])),
      filter("record.filter_is_nil", [3, 7], Ash.Expr.expr(is_nil(quantity))),
      filter("record.filter_not_nil", [1, 2, 4, 5, 6], Ash.Expr.expr(not is_nil(quantity))),
      filter("record.filter_not", [5, 6], Ash.Expr.expr(not (quantity > 2))),
      filter("record.filter_boolean", [2, 6], Ash.Expr.expr(active == false))
      |> requires(stored(:boolean)),
      filter("record.filter_atom", [1, 5, 6], Ash.Expr.expr(status == :live))
      |> requires(stored(:atom)),
      filter("record.filter_atom_as_string", [1, 5, 6], Ash.Expr.expr(status == "live"))
      |> requires(stored(:atom)),
      filter("record.filter_decimal", [2, 4], Ash.Expr.expr(price > 1.5))
      |> requires(stored(:decimal)),
      filter("record.filter_date", [1, 4], Ash.Expr.expr(born_on >= ^~D[2024-01-01]))
      |> requires(stored(:date)),
      filter(
        "record.filter_datetime_precision",
        [4],
        Ash.Expr.expr(seen_at > ^~U[2024-02-29 12:00:00.000000Z])
      )
      |> requires(stored(:utc_datetime_usec)),
      filter("record.filter_contains", [1, 2], Ash.Expr.expr(contains(name, "pp"))),
      filter(
        "record.filter_case_insensitive",
        [1, 2, 3],
        Ash.Expr.expr(contains(string_downcase(name), "apple"))
      ),
      filter("record.filter_unicode", [4], Ash.Expr.expr(name == "Ünïcode ✓")),
      filter("record.filter_empty_string", [6], Ash.Expr.expr(name == "")),
      filter("record.filter_array_member", [1, 4], Ash.Expr.expr("red" in tags))
      |> requires(stored(:strings)),
      filter("record.filter_map_key", [2], Ash.Expr.expr(metadata["size"] == "m"))
      |> requires(stored(:map)),
      filter("record.filter_embedded", [1, 4], Ash.Expr.expr(address[:city] == "Auckland"))
      |> requires(stored(:embedded)),
      filter("record.filter_calculation", [4], Ash.Expr.expr(double_quantity > 10)),
      # Ash documents `true or nil` as nil, unlike SQL, where it is true.
      filter(
        "record.filter_true_or_nil",
        :unresolved,
        Ash.Expr.expr(active == true or quantity > 5)
      )
    ]
  end

  defp sorting do
    [
      sort("record.sort_desc_nils_last", [4, 1, 2, 5, 6, 3, 7],
        quantity: :desc_nils_last,
        id: :asc
      ),
      sort("record.sort_asc_nils_first", [3, 7, 6, 5, 1, 2, 4],
        quantity: :asc_nils_first,
        id: :asc
      ),
      sort(
        "record.sort_tie_break",
        [2, 1],
        [quantity: :asc, id: :desc],
        Ash.Expr.expr(quantity == 3)
      ),
      sort("record.sort_string", [7, 6, 5, 4, 3, 2, 1], code: :desc),
      sort("record.sort_decimal", [6, 5, 1, 2, 4, 3, 7], price: :asc_nils_last, id: :asc)
      |> requires(stored(:decimal)),
      sort("record.sort_date", [2, 1, 4, 3, 5, 6, 7], born_on: :asc_nils_last, id: :asc)
      |> requires(stored(:date)),
      scenario("record.sort_calculation", :ordering, [4, 1, 2, 5, 6], @calculations, fn ctx ->
        ctx.record
        |> Ash.Query.filter(not is_nil(quantity))
        |> Ash.Query.sort(double_quantity: :desc, id: :asc)
        |> ids()
      end)
    ]
  end

  defp paging do
    [
      scenario("record.limit_offset", :pagination, [3, 4], @reads, fn ctx ->
        ctx |> query() |> Ash.Query.limit(2) |> Ash.Query.offset(2) |> ids()
      end),
      scenario("record.count", :pagination, {5, true, false}, @reads, fn ctx ->
        present = Ash.Query.filter(ctx.record, not is_nil(quantity))
        missing = Ash.Query.filter(ctx.record, quantity > 100)

        {Ash.count!(present, authorize?: false), Ash.exists?(present, authorize?: false),
         Ash.exists?(missing, authorize?: false)}
      end),
      scenario("record.stream", :pagination, [1, 2, 3, 4, 5, 6, 7], @reads, fn ctx ->
        ctx.record
        |> Ash.Query.for_read(:streamable)
        |> Ash.Query.sort(:id)
        |> Ash.stream!(batch_size: 2, authorize?: false)
        |> Enum.map(& &1.id)
      end),
      scenario(
        "record.offset_pages",
        :pagination,
        {[[1, 2, 3], [4, 5, 6], [7]], 7, false},
        @reads,
        fn ctx ->
          first = page(ctx, offset: 0, limit: 3, count: true)
          second = Ash.page!(first, :next)
          last = Ash.page!(second, :next)

          {Enum.map([first, second, last], &Enum.map(&1.results, fn r -> r.id end)), first.count,
           last.more?}
        end
      ),
      scenario("record.keyset_pages", :pagination, {[4, 5, 6], [1, 2, 3], 7}, @reads, fn ctx ->
        first = page(ctx, limit: 3, count: true)
        next = Ash.page!(first, :next)
        previous = Ash.page!(next, :prev)

        {Enum.map(next.results, & &1.id), Enum.map(previous.results, & &1.id), first.count}
      end),
      scenario(
        "record.calculation_load",
        :calculations,
        %{1 => 6, 3 => nil, 6 => -14},
        @calculations,
        fn ctx ->
          ctx.record
          |> Ash.Query.filter(id in [1, 3, 6])
          |> Ash.Query.load(:double_quantity)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1.double_quantity})
        end
      ),
      # String arguments are trimmed by default, so the suffix has no spaces.
      scenario("record.calculation_argument", :calculations, "apple-pie", @calculations, fn ctx ->
        ctx.record
        |> Ash.Query.filter(id == 1)
        |> Ash.Query.load(suffixed: %{suffix: "-pie"})
        |> Ash.read_one!(authorize?: false)
        |> Map.fetch!(:suffixed)
      end)
    ]
  end

  defp query_features do
    [
      # Children by label: high (13), other (21), same (11 and 12), nil (14).
      new(
        "query.distinct",
        :reads,
        [13, 21, 11, 14],
        fn ctx ->
          ctx.child
          |> Ash.Query.distinct(:label)
          |> Ash.Query.sort(label: :asc, id: :asc)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        semantic_basis: @query_docs,
        capabilities: [child: :distinct, child: :distinct_sort]
      ),
      new(
        "query.union",
        :reads,
        [11, 12, 13],
        fn ctx ->
          ctx.child
          |> Ash.Query.combination_of([
            Ash.Query.Combination.base(filter: Ash.Expr.expr(value == 2)),
            Ash.Query.Combination.union(filter: Ash.Expr.expr(value == 7))
          ])
          |> Ash.Query.sort(:id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)
        end,
        semantic_basis: "../documentation/topics/advanced/combination-queries.md",
        capabilities: [child: :combine, parent: {:combine, :union}]
      ),
      # Children: 11 and 12 are 2, 13 is 7, 21 is 4 and 14 is nil. `union_all`
      # keeps duplicates, `intersect` keeps rows in both, `except` drops them.
      new(
        "query.union_all",
        :reads,
        [11, 11, 12, 12],
        &combined(&1, Ash.Expr.expr(value == 2), :union_all, Ash.Expr.expr(value == 2)),
        combination_opts(:union_all)
      ),
      new(
        "query.intersect",
        :reads,
        [11, 12, 21],
        &combined(&1, Ash.Expr.expr(value >= 2), :intersect, Ash.Expr.expr(value <= 4)),
        combination_opts(:intersect)
      ),
      new(
        "query.except",
        :reads,
        [13, 21],
        &combined(&1, Ash.Expr.expr(value >= 2), :except, Ash.Expr.expr(value == 2)),
        combination_opts(:except)
      ),
      # Ash evaluates an expression calculation with explicit references in
      # memory before it would ask the data layer, on every data layer. The
      # evidence shows Ash did the work; it does not compare capabilities.
      new(
        "calc.in_memory",
        :calculations,
        42,
        fn ctx -> Ash.calculate!(ctx.child, :double_value, refs: %{value: 21}) end,
        semantic_basis: "../lib/ash/actions/read/calculations.ex",
        capabilities: [child: :calculate, child: :expression_calculation],
        fallback: "Ash evaluates the calculation itself, without the data layer"
      )
    ]
  end

  defp combined(ctx, base, type, filter) do
    ctx.child
    |> Ash.Query.combination_of([
      Ash.Query.Combination.base(filter: base),
      struct(Ash.Query.Combination, type: type, filter: filter)
    ])
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp combination_opts(type),
    do: [
      semantic_basis: "../lib/ash/query/combination.ex",
      capabilities: [child: :combine, child: {:combine, type}]
    ]
end
