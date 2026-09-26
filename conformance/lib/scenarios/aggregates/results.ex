# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Results do
  @moduledoc "Defaults, nils, uniqueness, names, value types and explicit nil ordering."
  import Ash.Conformance.Scenario, only: [new: 4, new: 5]
  import Ash.Conformance.Scenarios.Aggregates.Helpers
  require Ash.Query

  def all, do: semantics() ++ rejections()

  defp semantics do
    [
      new("values.field_count", :results, %{1 => 3, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, field: :value)
      end),
      new("values.distinct_count", :results, %{1 => 2, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, field: :value, uniq?: true)
      end),
      new("values.distinct_list", :results, %{1 => [2, 7], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children, field: :value, uniq?: true, query: [sort: [value: :asc]])
      end),
      new(
        "values.include_nil_list",
        :results,
        %{1 => [nil, 2, 2, 7], 2 => [4], 3 => []},
        fn ctx ->
          loaded(ctx, :list, :children,
            field: :value,
            include_nil?: true,
            query: [sort: [value: :asc_nils_first]]
          )
        end
      ),
      new("values.include_nil_first", :results, %{1 => nil, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          include_nil?: true,
          query: [sort: [value: :asc_nils_first]]
        )
      end),
      new("values.scalar_default", :results, %{1 => 11, 2 => 4, 3 => 0}, fn ctx ->
        loaded(ctx, :sum, :children, field: :value, default: 0)
      end),
      new("values.list_default", :results, %{1 => [2, 2, 7], 2 => [4], 3 => [99]}, fn ctx ->
        loaded(ctx, :list, :children, field: :value, default: [99], query: [sort: [value: :asc]])
      end),
      # With no sort the list order is unspecified, so it is sorted before
      # comparing. `include_nil?` defaults to false, so nil must not appear.
      new("values.list_unsorted", :results, %{1 => [2, 2, 7], 2 => [4], 3 => []}, fn ctx ->
        ctx
        |> loaded(:list, :children, field: :value)
        |> Map.new(fn {id, values} -> {id, Enum.sort(values)} end)
      end),
      new("root.list_unsorted", :operations, [2, 2, 4, 7], fn ctx ->
        ctx |> root(:list, field: :value) |> Enum.sort()
      end),
      # Descending order differs from both ID and insertion order, so a
      # dropped sort fails on every adapter.
      new("ordering.list_desc", :ordering, %{1 => [7, 2, 2], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children, field: :value, query: [sort: [value: :desc]])
      end),
      new("values.filtered_first_default", :results, %{1 => 99, 2 => 99, 3 => 99}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          default: 99,
          query: [filter: [value: [gt: 100]]]
        )
      end),
      new(
        "values.constrained_scalar",
        :results,
        %{1 => quantity(11), 2 => quantity(4), 3 => quantity(0)},
        fn ctx ->
          loaded(ctx, :sum, :children,
            field: :value,
            default: 0,
            type: Ash.Conformance.Resources.Quantity,
            constraints: [unit: :points]
          )
        end
      ),
      new(
        "values.string_constraints",
        :results,
        %{1 => ["same", "same", "high", "", " padded "], 2 => ["other"], 3 => []},
        fn ctx ->
          # Check string preservation independently of the database's text collation.
          loaded(ctx, :list, :children, field: :label, query: [sort: [id: :asc]])
        end,
        # An empty label and a padded one, which must come back unchanged.
        prepare: fn ctx ->
          Ash.Conformance.Fixtures.seed!(ctx.adapter, :child, [
            %{id: 15, parent_id: 1, label: ""},
            %{id: 16, parent_id: 1, label: " padded "}
          ])
        end
      ),
      new(
        "values.root_empty",
        :results,
        %{count: 0, sum: nil, first: nil, exists: false},
        fn ctx ->
          ctx.child
          |> Ash.Query.filter(id < 0)
          |> Ash.aggregate!(
            [
              {:count, :count},
              {:sum, :sum, field: :value},
              {:first, :first, field: :value, query: [sort: [value: :asc]]},
              {:exists, :exists}
            ],
            authorize?: false
          )
        end
      ),
      new("root.list_empty", :operations, [], fn ctx ->
        root(empty_input(ctx), :list, field: :value, query: [sort: [value: :asc]])
      end),
      new("root.list_default_empty", :operations, [99], fn ctx ->
        root(empty_input(ctx), :list,
          field: :value,
          default: [99],
          query: [sort: [value: :asc]]
        )
      end),
      new("root.custom_empty", :operations, nil, fn ctx ->
        root(empty_input(ctx), :custom,
          type: :integer,
          implementation: {ctx.adapter.custom_aggregate(), field: :value}
        )
      end),
      new("root.unsorted_first_empty", :operations, nil, fn ctx ->
        root(%{ctx | child: Ash.Query.filter(ctx.child, id < 0)}, :first, field: :value)
      end),
      new("values.same_name_distinct_definitions", :results, {11, 7}, fn ctx ->
        query =
          selected_parent(ctx) |> Ash.Query.aggregate(:total, :sum, :children, field: :value)

        original = Ash.read_one!(query, authorize?: false)

        replaced =
          query
          |> Ash.Query.aggregate(:total, :sum, :children,
            field: :value,
            query: [filter: [value: [gt: 3]]]
          )
          |> Ash.read_one!(authorize?: false)

        {original.aggregates.total, replaced.aggregates.total}
      end),
      new("values.string_name", :results, 11, fn ctx ->
        result =
          selected_parent(ctx)
          |> Ash.Query.aggregate("total", :sum, :children, field: :value)
          |> Ash.read_one!(authorize?: false)

        result.aggregates["total"]
      end)
    ] ++ null_sorts()
  end

  defp null_sorts do
    for {order, expected} <- [
          asc_nils_first: nil,
          asc_nils_last: 2,
          desc_nils_first: nil,
          desc_nils_last: 7
        ] do
      new("ordering.#{order}", :ordering, expected, fn ctx ->
        ctx = %{ctx | parent: selected_parent(ctx)}

        loaded(ctx, :first, :children,
          field: :value,
          include_nil?: true,
          query: [sort: [value: order]]
        )
        |> Map.fetch!(1)
      end)
    end
  end

  defp rejections do
    [
      # Ash allows `uniq?` only on count and list aggregates.
      new(
        "query.uniq_sum_rejected",
        :aggregates,
        {:error, Ash.Error.Unknown,
         ~r/sum aggregates do not support the `uniq\?` option\. Only count and list are supported currently\./},
        fn ctx ->
          ctx.parent
          |> Ash.Query.aggregate(:result, :sum, :children, field: :value, uniq?: true)
          |> Ash.read!(authorize?: false)
        end,
        semantic_basis: "../lib/ash/query/aggregate.ex"
      )
    ]
  end

  defp empty_input(ctx), do: %{ctx | child: Ash.Query.filter(ctx.child, id < 0)}

  defp quantity(value), do: %Ash.Conformance.Resources.Quantity{value: value, unit: :points}
end
