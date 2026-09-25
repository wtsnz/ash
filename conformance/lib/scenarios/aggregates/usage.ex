# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Usage do
  @moduledoc "Aggregates used in filters, sorts, pages and calculations, including through relationships."
  import Ash.Conformance.Scenario, only: [new: 4]
  import Ash.Conformance.Scenarios.Aggregates.Helpers
  require Ash.Query
  require Ash.Sort

  def all, do: query_uses() ++ related_uses()

  defp query_uses do
    [
      new("use.filter", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(child_sum > 5)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.sort", :usage, [2, 1, 3], fn ctx ->
        ctx.parent
        |> Ash.Query.sort(child_sum: :asc_nils_last)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.calculation", :usage, %{1 => 14, 2 => 9, 3 => 9}, fn ctx ->
        ctx.parent
        |> Ash.Query.load(:sum_plus_threshold)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{&1.id, &1.sum_plus_threshold})
      end),
      new("use.pagination", :usage, {[2], 3}, fn ctx ->
        page =
          ctx.parent
          |> Ash.Query.for_read(:paged)
          |> Ash.Query.load(:child_count)
          |> Ash.Query.sort(child_count: :desc)
          |> Ash.read!(page: [offset: 1, limit: 1, count: true], authorize?: false)

        {Enum.map(page.results, & &1.id), page.count}
      end),
      new("field.calculation", :expressions, %{1 => 22, 2 => 8, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children, field: :double_value)
      end),
      new("field.aggregate", :expressions, %{1 => 4, 2 => 0, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children, field: :rating_count)
      end),
      new("field.root_aggregate", :expressions, 5, fn ctx ->
        Ash.aggregate!(ctx.parent, [{:result, :sum, field: :child_count}], authorize?: false).result
      end),
      new("ordering.expression_first", :ordering, %{1 => 7, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          query: Ash.Query.sort(ctx.child, [{Ash.Sort.expr_sort(value * -1, :integer), :asc}])
        )
      end),
      new("ordering.expression_list", :ordering, %{1 => [7, 2, 2], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children,
          field: :value,
          query: Ash.Query.sort(ctx.child, [{Ash.Sort.expr_sort(value * -1, :integer), :asc}])
        )
      end),
      new("ordering.ties", :ordering, %{1 => [12, 11, 13], 2 => [21], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children,
          field: :id,
          query: [filter: [value: [is_nil: false]], sort: [value: :asc, id: :desc]]
        )
      end)
    ]
  end

  # Aggregates referenced through relationships, and reads that deduplicate
  # to-many filter joins. `use.fanout_read_page` fails if duplicate joined
  # rows fill the page.
  defp related_uses do
    [
      new("use.related_filter", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(children.rating_count > 1)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.related_exists", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(exists(children, rating_count > 1))
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.to_one_filter", :usage, [11, 12, 13, 14], fn ctx ->
        ctx.child
        |> Ash.Query.filter(parent.child_sum > 5)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.to_one_sort", :usage, [21, 11, 12, 13, 14], fn ctx ->
        ctx.child
        |> Ash.Query.sort([{Ash.Sort.expr_sort(parent.child_count, :integer), :asc}, id: :asc])
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.keyset_pagination", :usage, {[1, 2], [3]}, fn ctx ->
        query =
          ctx.parent
          |> Ash.Query.for_read(:keyset)
          |> Ash.Query.sort(child_count: :desc, id: :asc)

        first = Ash.read!(query, page: [limit: 2], authorize?: false)
        keyset = List.last(first.results).__metadata__.keyset
        next = Ash.read!(query, page: [limit: 2, after: keyset], authorize?: false)
        {Enum.map(first.results, & &1.id), Enum.map(next.results, & &1.id)}
      end),
      new(
        "use.nested_limited_load",
        :usage,
        %{1 => [{13, 1}, {11, 2}], 2 => [{21, 0}], 3 => []},
        fn ctx ->
          ctx.parent
          |> Ash.Query.load(top_children: :rating_count)
          |> Ash.read!(authorize?: false)
          |> Map.new(fn row ->
            {row.id, Enum.map(row.top_children, &{&1.id, &1.rating_count})}
          end)
        end
      ),
      new("use.fanout_count", :usage, 2, fn ctx ->
        ctx.child
        |> Ash.Query.filter(ratings.score > 5)
        |> Ash.count!(authorize?: false)
      end),
      new("use.fanout_read_page", :usage, {[11, 12], 2}, fn ctx ->
        page =
          ctx.child
          |> Ash.Query.filter(ratings.score > 5)
          |> Ash.Query.sort(id: :asc)
          |> Ash.read!(page: [limit: 2, count: true], authorize?: false)

        {Enum.map(page.results, & &1.id), page.count}
      end)
    ]
  end
end
