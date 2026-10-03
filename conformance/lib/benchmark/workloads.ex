# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Benchmark.Workloads do
  @moduledoc "Public API reads with independently calculated fixture answers."
  require Ash.Query

  def all(adapter, p, data) do
    parent = adapter.resource(:parent)
    child = adapter.resource(:child)

    root_aggregates = [
      {:count, :count},
      {:sum, :sum, field: :value},
      {:min, :min, field: :value},
      {:max, :max, field: :value}
    ]

    selected = Ash.Query.filter(parent, id <= ^p.selected) |> Ash.Query.sort(:id)
    grouped = Enum.group_by(data.children, & &1.parent_id)

    sums =
      Map.new(data.parents, fn row ->
        {row.id, grouped |> Map.get(row.id, []) |> Enum.map(& &1.value) |> Enum.sum()}
      end)

    [
      %{
        id: "loaded_counts_sums",
        operation: fn ->
          selected |> Ash.Query.load([:child_count, :child_sum]) |> Ash.read!(authorize?: false)
        end,
        project: fn rows -> Enum.map(rows, &{&1.id, &1.child_count, &1.child_sum}) end,
        expected: for(id <- 1..p.selected, do: {id, length(grouped[id]), sums[id]})
      },
      %{
        id: "ordered_first_list",
        operation: fn ->
          selected
          |> Ash.Query.aggregate(:ordered_first, :first, :children,
            field: :value,
            query: [sort: [value: :desc, id: :asc]]
          )
          |> Ash.Query.aggregate(:ordered_list, :list, :children,
            field: :value,
            query: [sort: [value: :desc, id: :asc]]
          )
          |> Ash.read!(authorize?: false)
        end,
        project: fn rows ->
          Enum.map(rows, &{&1.id, &1.aggregates.ordered_first, &1.aggregates.ordered_list})
        end,
        expected:
          for(
            id <- 1..p.selected,
            values = grouped[id] |> Enum.sort_by(&{-&1.value, &1.id}) |> Enum.map(& &1.value),
            do: {id, hd(values), values}
          )
      },
      %{
        id: "aggregate_filter_sort",
        operation: fn ->
          parent
          |> Ash.Query.filter(child_sum > 0)
          |> Ash.Query.sort(child_sum: :desc, id: :asc)
          |> Ash.Query.limit(p.selected)
          |> Ash.read!(authorize?: false)
        end,
        project: fn rows -> Enum.map(rows, & &1.id) end,
        expected:
          sums
          |> Enum.filter(fn {_, sum} -> sum > 0 end)
          |> Enum.sort_by(fn {id, sum} -> {-sum, id} end)
          |> Enum.take(p.selected)
          |> Enum.map(&elem(&1, 0))
      },
      %{
        id: "many_to_many",
        operation: fn ->
          selected
          |> Ash.Query.aggregate(:tag_sum, :sum, :tags, field: :value)
          |> Ash.read!(authorize?: false)
        end,
        project: fn rows -> Enum.map(rows, &{&1.id, &1.aggregates.tag_sum}) end,
        expected:
          for(
            id <- 1..p.selected,
            do:
              {id,
               data.links
               |> Enum.filter(&(&1.parent_id == id))
               |> Enum.map(&(&1.tag_id * 10))
               |> Enum.sum()}
          )
      },
      %{
        id: "root_aggregates",
        operation: fn ->
          Ash.aggregate!(child, root_aggregates, authorize?: false)
        end,
        project: &Function.identity/1,
        expected: %{
          count: length(data.children),
          sum: Enum.sum(Enum.map(data.children, & &1.value)),
          min: Enum.min(Enum.map(data.children, & &1.value)),
          max: Enum.max(Enum.map(data.children, & &1.value))
        }
      },
      %{
        id: "tenant_aggregates",
        operation: fn ->
          adapter.resource(:tenant_parent)
          |> Ash.Query.filter(local_id <= ^p.selected)
          |> Ash.Query.load([:item_count, :item_sum])
          |> Ash.Query.sort(:local_id)
          |> Ash.read!(tenant: 1, authorize?: false)
        end,
        project: fn rows -> Enum.map(rows, &{&1.local_id, &1.item_count, &1.item_sum}) end,
        expected: for(id <- 1..min(p.selected, p.tenant_size), do: {id, 1, id + 1})
      }
    ]
  end
end
