# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Queries do
  @moduledoc """
  Query features that data layers opt into: distinct, combinations and locks.

  Ash rejects each with a documented error when the data layer does not
  advertise it. Those rejections are the expected unsupported results.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query
  require Ash.Expr

  @query_docs "../lib/ash/query/query.ex"

  def all do
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
      new(
        "query.lock_for_update",
        :reads,
        {:ok, [11]},
        fn ctx ->
          Ash.transact(ctx.child, fn ->
            ctx.child
            |> Ash.Query.lock(:for_update)
            |> Ash.Query.filter(id == 11)
            |> Ash.read!(authorize?: false)
            |> Enum.map(& &1.id)
          end)
        end,
        semantic_basis: @query_docs,
        capabilities: [parent: {:lock, :for_update}, child: :transact]
      ),
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
end
