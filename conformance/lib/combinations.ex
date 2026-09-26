# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Combinations do
  @moduledoc """
  Pairwise feature combinations: aggregates combined with relationship
  shapes, aggregate filters, tenants, policies and how the aggregate is used.

  Each axis has a default. A single case changes one axis from the defaults;
  a pairwise case changes several. The pairwise cases cover every pair of
  axis values at least once (a greedy all-pairs set, fixed by the axis order
  below). Each pairwise case requires the base case and the single case for
  every value it changes, so a failure is blamed on the combination only
  when each feature works alone.

  Owners have items (`owner_id`), their top two items by value, and items
  linked through a join table. Items carry a tenant, a value, a status and
  the user who may read them. The expected answer comes from `reference/2`,
  which applies Ash's order, each step settled by an existing scenario:

  1. the relationship's members;
  2. the tenant, before any bounds (`tenant.bounds`);
  3. the item read policy, before any bounds
     (`context.authorization_before_bounds`);
  4. the relationship's sort and limit;
  5. the aggregate's own filter, after the limit (`bounds.filter_after_limit`);
  6. the aggregate: `count`, `sum` and `max` skip nil values, `list` skips
     them and sorts by `id`, and `exists` is whether anything is left.
  """

  @axes [
    kind: [:count, :sum, :max, :list, :exists],
    relationship: [:items, :top_items, :linked_items],
    filter: [:none, :value_gt, :open],
    tenant: [:global, :tenant],
    policy: [:off, :actor],
    use: [:loaded, :page, :sort, :filter]
  ]

  @actor %{id: 1}
  @tenant "a"

  def axes, do: @axes
  def defaults, do: Map.new(@axes, fn {axis, [default | _]} -> {axis, default} end)

  # {id, owner_id, tenant, value, status, seen_by}
  @items [
    {11, 1, "a", 5, "open", 1},
    {12, 1, "b", 3, "closed", 1},
    {13, 1, "a", nil, "open", 2},
    {14, 1, "a", 1, "closed", 1},
    {15, 1, "a", 6, "open", 2},
    {21, 2, "a", 4, "open", 2},
    {22, 2, "b", 7, "open", 1},
    {23, 2, "a", 2, "closed", 1}
  ]

  # {owner_id, item_id}: membership through the join table, unlike `owner_id`.
  @links [{1, 21}, {1, 22}, {2, 11}, {2, 13}, {2, 15}, {3, 12}]

  def owners, do: for(id <- [1, 2, 3], do: %{id: id, label: "owner-#{id}"})

  def items do
    for {id, owner_id, tenant, value, status, seen_by} <- @items,
        do: %{
          id: id,
          owner_id: owner_id,
          tenant: tenant,
          value: value,
          status: status,
          seen_by: seen_by
        }
  end

  def links,
    do:
      for(
        {{owner_id, item_id}, index} <- Enum.with_index(@links, 1),
        do: %{id: index, owner_id: owner_id, item_id: item_id}
      )

  @doc "The name of the owner aggregate a case reads."
  def aggregate_name(%{kind: kind, relationship: relationship, filter: filter}),
    do: :"#{kind}_#{relationship}_#{filter}"

  @doc "Every aggregate the owner resource defines: one per kind, relationship and filter."
  def aggregates do
    for kind <- @axes[:kind],
        relationship <- @axes[:relationship],
        filter <- @axes[:filter],
        do: %{kind: kind, relationship: relationship, filter: filter}
  end

  # A list has no order or threshold to use outside the aggregate.
  def valid?(%{kind: :list, use: use}) when use in [:sort, :filter], do: false
  def valid?(_case), do: true

  @doc "The base case, one single case per non-default value, then the pairwise cases."
  def cases do
    base = defaults()

    singles =
      for {axis, [_default | values]} <- @axes,
          value <- values,
          valid?(Map.put(base, axis, value)),
          do: Map.put(base, axis, value)

    [base] ++ singles ++ Enum.filter(pairwise(), &(changed(&1) |> length() > 1))
  end

  @doc "The axes a case changes from the defaults, in axis order."
  def changed(test_case) do
    defaults = defaults()
    for {axis, _values} <- @axes, test_case[axis] != defaults[axis], do: axis
  end

  def scenario_id(test_case) do
    case changed(test_case) do
      [] -> "combo.base"
      [axis] -> "combo.#{axis}.#{test_case[axis]}"
      _axes -> "combo." <> Enum.map_join(@axes, ".", fn {axis, _} -> test_case[axis] end)
    end
  end

  @doc "The base and single cases a case builds on."
  def requires(test_case) do
    case changed(test_case) do
      [] ->
        []

      axes ->
        base = defaults()
        singles = for axis <- axes, do: scenario_id(Map.put(base, axis, test_case[axis]))
        if length(axes) == 1, do: ["combo.base"], else: ["combo.base" | singles]
    end
  end

  # Greedy all-pairs: while a pair of values is uncovered, start a case from
  # the first one, then give each other axis the value that covers the most
  # uncovered pairs. Deterministic, because every choice takes the first best.
  defp pairwise do
    uncovered = MapSet.new(all_pairs())
    build(uncovered, [])
  end

  defp all_pairs do
    indexed = Enum.with_index(@axes)

    for {{a, a_values}, i} <- indexed,
        {{b, b_values}, j} <- indexed,
        i < j,
        va <- a_values,
        vb <- b_values,
        valid?(%{a => va, b => vb}),
        do: {{a, va}, {b, vb}}
  end

  defp build(uncovered, cases) do
    if MapSet.size(uncovered) == 0 do
      Enum.reverse(cases)
    else
      {{a, va}, {b, vb}} = uncovered |> Enum.sort() |> hd()
      seed = %{a => va, b => vb}

      test_case =
        Enum.reduce(@axes, seed, fn {axis, values}, acc ->
          if Map.has_key?(acc, axis) do
            acc
          else
            best =
              values
              |> Enum.filter(&valid?(Map.put(acc, axis, &1)))
              |> Enum.max_by(&covered(Map.put(acc, axis, &1), uncovered), fn -> hd(values) end)

            Map.put(acc, axis, best)
          end
        end)

      build(MapSet.difference(uncovered, pairs_of(test_case)), [test_case | cases])
    end
  end

  defp covered(partial, uncovered),
    do: partial |> pairs_of() |> MapSet.intersection(uncovered) |> MapSet.size()

  defp pairs_of(test_case) do
    set = for {axis, _} <- @axes, Map.has_key?(test_case, axis), do: {axis, test_case[axis]}

    MapSet.new(
      for {x, i} <- Enum.with_index(set), {y, j} <- Enum.with_index(set), i < j, do: {x, y}
    )
  end

  @doc "The answer Ash defines for a case, from the fixture data."
  def reference(test_case) do
    values = Map.new(owners(), &{&1.id, value(test_case, &1.id)})

    case test_case.use do
      :loaded -> values
      :page -> {Map.take(values, [2, 3]), 3}
      :sort -> sorted_owners(values)
      :filter -> values |> Enum.filter(fn {_id, v} -> above?(test_case.kind, v) end) |> ids()
    end
  end

  defp ids(pairs), do: pairs |> Enum.map(&elem(&1, 0)) |> Enum.sort()

  # Descending with nils last, then by id: `true` sorts before `false`.
  defp sorted_owners(values) do
    {present, missing} = Enum.split_with(values, fn {_id, v} -> not is_nil(v) end)
    rank = fn v -> if is_boolean(v), do: if(v, do: 1, else: 0), else: v end

    Enum.map(Enum.sort_by(present, fn {id, v} -> {-rank.(v), id} end), &elem(&1, 0)) ++
      Enum.sort(Enum.map(missing, &elem(&1, 0)))
  end

  @doc "The threshold the filter use compares an aggregate against."
  def threshold(:count), do: 1
  def threshold(kind) when kind in [:sum, :max], do: 4
  def threshold(:exists), do: true

  defp above?(:exists, value), do: value == true
  defp above?(kind, value), do: not is_nil(value) and value > threshold(kind)

  defp value(test_case, owner_id) do
    test_case.relationship
    |> members(owner_id)
    |> Enum.filter(&visible?(test_case, &1))
    |> bound(test_case.relationship)
    |> Enum.filter(&keep?(test_case.filter, &1))
    |> fold(test_case.kind)
  end

  # The tenant and the item read policy, both before any bounds.
  defp visible?(test_case, item) do
    (test_case.tenant == :global or item.tenant == @tenant) and
      (test_case.policy == :off or item.seen_by == @actor.id)
  end

  defp members(:linked_items, owner_id) do
    ids = for {^owner_id, item_id} <- @links, do: item_id
    Enum.filter(items(), &(&1.id in ids))
  end

  defp members(_relationship, owner_id), do: Enum.filter(items(), &(&1.owner_id == owner_id))

  defp bound(items, :top_items) do
    {present, missing} = Enum.split_with(items, &(not is_nil(&1.value)))

    (Enum.sort_by(present, &{-&1.value, &1.id}) ++ Enum.sort_by(missing, & &1.id))
    |> Enum.take(2)
  end

  defp bound(items, _relationship), do: items

  defp keep?(:none, _item), do: true
  defp keep?(:value_gt, item), do: not is_nil(item.value) and item.value > 2
  defp keep?(:open, item), do: item.status == "open"

  defp fold(items, :count), do: length(items)
  defp fold(items, :exists), do: items != []

  defp fold(items, :list),
    do: items |> Enum.sort_by(& &1.id) |> Enum.map(& &1.value) |> Enum.reject(&is_nil/1)

  defp fold(items, kind) do
    case items |> Enum.map(& &1.value) |> Enum.reject(&is_nil/1) do
      [] -> nil
      values when kind == :sum -> Enum.sum(values)
      values when kind == :max -> Enum.max(values)
    end
  end

  @doc "Runs a case against the adapter's owner resource."
  def run(adapter, test_case) do
    name = aggregate_name(test_case)
    owner = adapter.resource(:combo_owner)
    opts = read_opts(test_case)

    case test_case.use do
      :loaded ->
        owner |> Ash.Query.sort(:id) |> Ash.Query.load(name) |> Ash.read!(opts) |> by_id(name)

      :page ->
        page =
          owner
          |> Ash.Query.for_read(:paged)
          |> Ash.Query.sort(:id)
          |> Ash.Query.load(name)
          |> Ash.read!(Keyword.put(opts, :page, limit: 2, offset: 1, count: true))

        {by_id(page.results, name), page.count}

      :sort ->
        owner
        |> Ash.Query.sort([{name, :desc_nils_last}, {:id, :asc}])
        |> Ash.read!(opts)
        |> Enum.map(& &1.id)

      :filter ->
        statement =
          if test_case.kind == :exists,
            do: [{name, true}],
            else: [{name, [greater_than: threshold(test_case.kind)]}]

        owner
        |> Ash.Query.do_filter(statement)
        |> Ash.Query.sort(:id)
        |> Ash.read!(opts)
        |> Enum.map(& &1.id)
    end
  end

  defp by_id(records, name), do: Map.new(records, &{&1.id, Map.fetch!(&1, name)})

  defp read_opts(test_case) do
    tenant = if test_case.tenant == :tenant, do: [tenant: @tenant], else: []

    policy =
      if test_case.policy == :actor,
        do: [authorize?: true, actor: @actor],
        else: [authorize?: false]

    tenant ++ policy
  end
end
