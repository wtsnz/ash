# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Benchmark.Dataset do
  @moduledoc "Deterministic datasets, independently varied by command options."

  def parameters(:smoke),
    do: %{
      parents: 20,
      children: 4,
      selected: 5,
      tenants: 2,
      tenant_size: 10,
      skew: 0,
      unrelated: 100
    }

  def parameters(:large),
    do: %{
      parents: 1000,
      children: 50,
      selected: 20,
      tenants: 5,
      tenant_size: 2000,
      skew: 5000,
      unrelated: 100_000
    }

  def build(p) do
    parents =
      for id <- 1..p.parents, do: %{id: id, label: "parent-#{id}", threshold: 0, tenant_id: "a"}

    {groups, _} =
      Enum.map_reduce(parents, 1, fn parent, next_id ->
        count =
          p.children + if(parent.id == 1, do: p.skew, else: 0) +
            if(parent.id == p.parents, do: p.unrelated, else: 0)

        rows =
          for i <- range(count),
              do: %{
                id: next_id + i - 1,
                parent_id: parent.id,
                value: rem(i, 17) + 1,
                visible: true,
                tenant_id: "a",
                label: "item"
              }

        {rows, next_id + count}
      end)

    children = List.flatten(groups)
    tags = for id <- 1..3, do: %{id: id, label: "tag-#{id}", value: id * 10}

    links =
      for parent <- parents,
          tag <- tags,
          rem(parent.id + tag.id, 2) == 0,
          do: %{parent_id: parent.id, tag_id: tag.id, tenant_id: "a"}

    tenant_parents =
      for t <- 1..p.tenants,
          local <- 1..p.tenant_size,
          do: %{
            id: (t - 1) * p.tenant_size + local,
            tenant_id: t,
            local_id: local,
            owner_id: 1,
            name: "tenant-parent"
          }

    tenant_items =
      Enum.map(tenant_parents, fn row ->
        %{
          id: row.id,
          tenant_id: row.tenant_id,
          local_id: row.local_id,
          parent_key: row.local_id,
          owner_id: 1,
          department: 1,
          value: row.local_id + row.tenant_id
        }
      end)

    %{
      parents: parents,
      children: children,
      tags: tags,
      links: links,
      tenant_parents: tenant_parents,
      tenant_items: tenant_items
    }
  end

  def seed!(adapter, data) do
    for {role, rows} <- [
          parent: data.parents,
          child: data.children,
          tag: data.tags,
          link: data.links,
          tenant_parent: data.tenant_parents,
          tenant_item: data.tenant_items
        ] do
      adapter.benchmark_persist!(role, rows)
    end
  end

  defp range(0), do: []
  defp range(n), do: 1..n
end
