# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Large do
  @moduledoc """
  Data past the sizes the other fixtures reach: long `in` lists, a bulk
  create with more bind parameters than SQLite (32,766) or Postgres (65,535)
  allow in one statement, a deep offset, a full keyset walk and an aggregate
  over every row. Answers follow from the rows: `value` is the `id`, from 1
  to 2,000. Runs on data layers that opt in to `:large`.
  """
  require Ash.Query
  import Ash.Conformance.Scenario, only: [new: 5]

  @reads "../documentation/topics/actions/read-actions.md"
  @bulk "../documentation/topics/actions/create-actions.md"
  @pagination "../documentation/topics/advanced/pagination.livemd"
  @opts [fixture: :large]

  def all do
    [
      new(
        "large.in_list",
        :reads,
        1_000,
        fn ctx ->
          odd = Enum.to_list(1..1_999//2)
          ctx.adapter.resource(:large_row) |> Ash.Query.filter(id in ^odd) |> count()
        end,
        [semantic_basis: @reads] ++ @opts
      ),
      new(
        "large.in_list_strings",
        :reads,
        1_200,
        fn ctx ->
          labels = for id <- 1..1_200, do: "row-#{id}"
          ctx.adapter.resource(:large_row) |> Ash.Query.filter(label in ^labels) |> count()
        end,
        [semantic_basis: @reads] ++ @opts
      ),
      # 22,000 rows of three fields in one batch: 66,000 bind parameters, more
      # than SQLite or Postgres allow in one statement. Ash takes the batch
      # size as given, so the data layer must split the insert.
      new(
        "large.bulk_create_parameters",
        :writes,
        {:success, 24_000},
        fn ctx ->
          resource = ctx.adapter.resource(:large_row)
          inputs = for id <- 10_001..32_000, do: %{id: id, value: id, label: "bulk-#{id}"}

          result =
            Ash.bulk_create(inputs, resource, :create, batch_size: 22_000, authorize?: false)

          {result.status, count(resource)}
        end,
        [semantic_basis: @bulk] ++ @opts
      ),
      new(
        "large.offset_deep",
        :pagination,
        Enum.to_list(1_991..2_000),
        fn ctx ->
          ctx.adapter.resource(:large_row)
          |> Ash.Query.for_read(:paged)
          |> Ash.Query.sort(:id)
          |> Ash.read!(page: [limit: 20, offset: 1_990], authorize?: false)
          |> Map.fetch!(:results)
          |> Enum.map(& &1.id)
        end,
        [semantic_basis: @pagination] ++ @opts
      ),
      # Eight pages of 250, Ash's default largest page, in order, with
      # nothing missed or repeated.
      new(
        "large.keyset_walk",
        :pagination,
        {List.duplicate(250, 8), true},
        fn ctx ->
          pages =
            ctx.adapter.resource(:large_row)
            |> Ash.Query.for_read(:keyset_paged)
            |> Ash.Query.sort(:id)
            |> Ash.read!(page: [limit: 250], authorize?: false)
            |> walk([])

          {Enum.map(pages, &length/1), List.flatten(pages) == Enum.to_list(1..2_000)}
        end,
        [semantic_basis: @pagination] ++ @opts
      ),
      new(
        "large.sum",
        :aggregates,
        2_001_000,
        fn ctx ->
          Ash.sum!(ctx.adapter.resource(:large_row), :value, authorize?: false)
        end,
        [semantic_basis: "../documentation/topics/resources/aggregates.md"] ++ @opts
      )
    ]
  end

  defp count(query), do: Ash.count!(query, authorize?: false)

  defp walk(page, pages) when length(pages) < 10 do
    pages = [Enum.map(page.results, & &1.id) | pages]
    if page.more?, do: walk(Ash.page!(page, :next), pages), else: Enum.reverse(pages)
  end

  defp walk(_page, pages), do: Enum.reverse(pages)
end
