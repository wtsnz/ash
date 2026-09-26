# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.IsolationHelpers do
  @moduledoc "Queries and projections shared by the tenancy, authorization and consistency scenarios."
  require Ash.Query

  def query(ctx, role, tenant), do: ctx.adapter.resource(role) |> Ash.Query.set_tenant(tenant)

  def authorized(ctx, role, actor, tenant \\ 1) do
    query(ctx, role, tenant)
    |> Ash.Query.for_read(:read, %{}, actor: %{id: actor}, authorize?: true)
  end

  def contextual(ctx, role) do
    authorized(ctx, role, 1) |> Ash.Query.set_context(%{shared: %{department: 1}})
  end

  def values(ctx, role, tenant, local_ids \\ nil) do
    query(ctx, role, tenant)
    |> then(fn query ->
      if local_ids, do: Ash.Query.filter(query, local_id in ^local_ids), else: query
    end)
    |> Ash.Query.sort(:local_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.local_id, &1.value})
  end

  def ids(query, sort? \\ true) do
    query = if sort?, do: Ash.Query.sort(query, :local_id), else: query
    query |> Ash.read!() |> Enum.map(& &1.local_id)
  end

  def relationships(query, name) do
    query
    |> Ash.Query.load(name)
    |> Ash.read!()
    |> unique_map(fn row ->
      {row.local_id, row |> Map.fetch!(name) |> List.wrap() |> Enum.map(& &1.id)}
    end)
  end

  def totals(query) do
    query
    |> Ash.Query.load([:item_count, :item_sum])
    |> Ash.read!()
    |> unique_map(&{&1.local_id, {&1.item_count, &1.item_sum}})
  end

  # Local IDs repeat across tenants. A row leaked from another tenant would
  # silently replace its namesake in a map, so a repeated key raises instead.
  defp unique_map(rows, pair) do
    Enum.reduce(rows, %{}, fn row, acc ->
      {key, value} = pair.(row)

      if Map.has_key?(acc, key),
        do: raise("local ID #{inspect(key)} appears twice; a row leaked from another tenant")

      Map.put(acc, key, value)
    end)
  end

  def root(query), do: Ash.aggregate!(query, [{:count, :count}, {:sum, :sum, field: :value}])

  def page_result(page), do: {Enum.map(page.results, & &1.local_id), page.count, page.more?}

  def keyset_pages(query, after_key \\ nil, ids \\ [], counts \\ []) do
    page_opts = [limit: 1, count: true] ++ if(after_key, do: [after: after_key], else: [])
    page = Ash.read!(query, page: page_opts)
    ids = ids ++ Enum.map(page.results, & &1.local_id)
    counts = counts ++ [page.count]

    if page.more? do
      keyset_pages(query, List.last(page.results).__metadata__.keyset, ids, counts)
    else
      {ids, counts}
    end
  end
end
