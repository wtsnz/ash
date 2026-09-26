# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Shapes do
  @moduledoc """
  The shapes grid: aggregates and `exists` over relationship paths of one to
  three hops, on integer- and UUID-keyed destinations, with rows missing at
  every level. Unlike the combination grid, it runs every combination of its
  axes, because the bugs it looks for need three at once (a multi-hop path,
  an `exists`, and no or a constant condition).

  Roots (integer keys) have mids, mids have leaves, leaves have tips. Each
  level exists twice, keyed by integers and by UUIDs, with the same data:

      root 1: mid 11 (5) - leaf 111 (4) - tip 1111 (3)
                         - leaf 112 (1)
              mid 12 (1) - leaf 121 (6) - tip 1211 (1)
      root 2: mid 21 (3) - leaf 211 (2)
      root 3: mid 31 (2)
      root 4: no mids
      no root: mid 51 (7) - leaf 511 (9) - tip 5111 (8)

  Root 3 has a mid but nothing below it, and root 2 a leaf but no tip, so an
  `exists` over the full path is false for them. Mid 51 has no root, for the
  related calculation cases: `root_label` on a mid reads its root's label.

  Axes:
  - `key`: `:integer` or `:uuid` destinations;
  - `depth`: 1, 2 or 3 hops;
  - `predicate`: `:none`, `:constant` (`true`) or `:field` (`value > 2`);
  - `kind`: `count`, `exists` or `sum` (of `value`);
  - `use`: the aggregate `loaded`, used in a `sort` or a `filter`, or
    `exists_expr`, a read filtered by `exists(path, predicate)`.

  Each case requires the same kind and use on a one-hop, integer-keyed path
  with no condition, so a failure is blamed on depth, key or condition only
  when the aggregate itself works.
  """

  @axes [
    key: [:integer, :uuid],
    depth: [1, 2, 3],
    predicate: [:none, :constant, :field],
    kind: [:count, :exists, :sum],
    use: [:loaded, :sort, :filter, :exists_expr]
  ]

  def axes, do: @axes

  # {level, id, parent id, value}
  @mids [{11, 1, 5}, {12, 1, 1}, {21, 2, 3}, {31, 3, 2}, {51, nil, 7}]
  @leaves [{111, 11, 4}, {112, 11, 1}, {121, 12, 6}, {211, 21, 2}, {511, 51, 9}]
  @tips [{1111, 111, 3}, {1211, 121, 1}, {5111, 511, 8}]

  def roots, do: for(id <- 1..4, do: %{id: id, label: "root-#{id}"})

  @doc "A level's rows for a key type, with UUID keys derived from the integer ones."
  def rows(:mids, key),
    do: for({id, root, v} <- @mids, do: %{id: key(key, id), root_id: root, value: v})

  def rows(:leaves, key),
    do: for({id, mid, v} <- @leaves, do: %{id: key(key, id), mid_id: key(key, mid), value: v})

  def rows(:tips, key),
    do: for({id, leaf, v} <- @tips, do: %{id: key(key, id), leaf_id: key(key, leaf), value: v})

  def key(:integer, id), do: id

  def key(:uuid, id),
    do: "00000000-0000-4000-8000-" <> String.pad_leading(Integer.to_string(id), 12, "0")

  @doc "Every valid combination of the axes."
  def cases do
    for key <- @axes[:key],
        depth <- @axes[:depth],
        predicate <- @axes[:predicate],
        kind <- @axes[:kind],
        use <- @axes[:use],
        test_case = %{key: key, depth: depth, predicate: predicate, kind: kind, use: use},
        valid?(test_case),
        do: test_case
  end

  # `exists(path, predicate)` is a boolean expression: it has no kind of its
  # own, and needs a predicate.
  def valid?(%{use: :exists_expr, kind: kind}) when kind != :exists, do: false
  def valid?(%{use: :exists_expr, predicate: :none}), do: false
  def valid?(_case), do: true

  def scenario_id(%{key: key, depth: depth, predicate: predicate, kind: kind, use: use}),
    do: "shape.#{kind}.#{key}.depth_#{depth}.#{predicate}.#{use}"

  @doc "The one-hop, integer-keyed case with no condition that a case builds on."
  def control(test_case) do
    %{test_case | key: :integer, depth: 1, predicate: control_predicate(test_case.use)}
  end

  defp control_predicate(:exists_expr), do: :constant
  defp control_predicate(_use), do: :none

  def requires(test_case) do
    control = control(test_case)
    if control == test_case, do: [], else: [scenario_id(control)]
  end

  @doc "The name of the root aggregate a case reads."
  def aggregate_name(%{key: key, depth: depth, predicate: predicate, kind: kind}),
    do: :"#{kind}_#{key}_#{depth}_#{predicate}"

  @doc "Every aggregate the root resource defines."
  def aggregates do
    for key <- @axes[:key],
        depth <- @axes[:depth],
        predicate <- @axes[:predicate],
        kind <- @axes[:kind],
        do: %{key: key, depth: depth, predicate: predicate, kind: kind}
  end

  @doc "The relationship path of a depth, from the root."
  def path(key, depth), do: Enum.take([:"#{key}_mids", :leaves, :tips], depth)

  @doc "The answer Ash defines for a case, from the fixture data."
  def reference(test_case) do
    values = Map.new(roots(), &{&1.id, value(test_case, &1.id)})

    case test_case.use do
      :loaded -> values
      :sort -> sorted(values)
      :filter -> for({id, v} <- Enum.sort(values), above?(test_case.kind, v), do: id)
      :exists_expr -> for({id, true} <- Enum.sort(values), do: id)
    end
  end

  defp value(test_case, root_id) do
    test_case.depth
    |> members(root_id)
    |> Enum.filter(&keep?(test_case.predicate, &1))
    |> fold(test_case.kind)
  end

  defp members(depth, root_id) do
    mids = for {id, ^root_id, v} <- @mids, do: {id, v}
    leaves = for {id, mid, v} <- @leaves, Enum.any?(mids, &(elem(&1, 0) == mid)), do: {id, v}
    tips = for {id, leaf, v} <- @tips, Enum.any?(leaves, &(elem(&1, 0) == leaf)), do: {id, v}
    Enum.at([mids, leaves, tips], depth - 1)
  end

  defp keep?(:field, {_id, value}), do: value > 2
  defp keep?(_predicate, _row), do: true

  defp fold(rows, :count), do: length(rows)
  defp fold(rows, :exists), do: rows != []
  defp fold([], :sum), do: nil
  defp fold(rows, :sum), do: rows |> Enum.map(&elem(&1, 1)) |> Enum.sum()

  # Descending with nils last, then by id; `true` sorts before `false`.
  defp sorted(values) do
    rank = fn
      nil -> {1, 0}
      true -> {0, -1}
      false -> {0, 0}
      v -> {0, -v}
    end

    values |> Enum.sort_by(fn {id, v} -> {rank.(v), id} end) |> Enum.map(&elem(&1, 0))
  end

  def threshold(:count), do: 1
  def threshold(:sum), do: 5
  def threshold(:exists), do: true

  defp above?(:exists, value), do: value == true
  defp above?(kind, value), do: not is_nil(value) and value > threshold(kind)

  @doc "Runs a case against the adapter's root resource."
  def run(adapter, test_case) do
    root = adapter.resource(:shape_root)
    opts = [authorize?: Ash.Conformance.Variant.authorize?()]

    case test_case.use do
      :exists_expr ->
        root
        |> Ash.Query.do_filter(
          Ash.Query.Exists.new(path(test_case.key, test_case.depth), predicate(test_case))
        )
        |> Ash.Query.sort(:id)
        |> Ash.read!(opts)
        |> Enum.map(& &1.id)

      use ->
        name = aggregate_name(test_case)

        query =
          case use do
            :loaded ->
              root |> Ash.Query.load(name) |> Ash.Query.sort(:id)

            :sort ->
              Ash.Query.sort(root, [{name, :desc_nils_last}, {:id, :asc}])

            :filter ->
              statement =
                if test_case.kind == :exists,
                  do: [{name, true}],
                  else: [{name, [greater_than: threshold(test_case.kind)]}]

              root |> Ash.Query.do_filter(statement) |> Ash.Query.sort(:id)
          end

        records = Ash.read!(query, opts)

        if use == :loaded,
          do: Map.new(records, &{&1.id, Map.fetch!(&1, name)}),
          else: Enum.map(records, & &1.id)
    end
  end

  defp predicate(%{predicate: :constant}), do: true

  defp predicate(%{predicate: :field}) do
    require Ash.Expr
    Ash.Expr.expr(value > 2)
  end

  @doc """
  Related calculation cases: each mid reads its root's label, loaded or used
  in a sort. The calculation is written inline (`expr(root.label)`) or as a
  module returning a lone `^ref([:root], :label)`
  (`Ash.Conformance.Resources.RefCalculation`). Mid 51 has no root, so its
  label is nil and it must still be returned.
  """
  def related_cases,
    do:
      for(
        key <- @axes[:key],
        form <- [:inline, :module],
        use <- [:loaded, :sort],
        do: {key, form, use}
      )

  def related_id({key, form, use}), do: "shape.related_calc.#{key}.#{form}.#{use}"

  def related_reference({key, _form, use}), do: related_reference({key, use})

  def related_reference({key, :loaded}) do
    labels = %{1 => "root-1", 2 => "root-2", 3 => "root-3", nil => nil}
    Map.new(@mids, fn {id, root, _v} -> {key(key, id), labels[root]} end)
  end

  # By root label ascending with nils last, then by value: mid 12 (1) before 11 (5).
  def related_reference({key, :sort}),
    do: Enum.map([12, 11, 21, 31, 51], &key(key, &1))

  def related_run(adapter, {key, form, use}) do
    mid = adapter.resource(:"shape_#{key}_mid")
    calculation = if form == :inline, do: :root_label, else: :root_label_module
    opts = [authorize?: Ash.Conformance.Variant.authorize?()]

    case use do
      :loaded ->
        mid
        |> Ash.Query.load(calculation)
        |> Ash.read!(opts)
        |> Map.new(&{&1.id, Map.fetch!(&1, calculation)})

      :sort ->
        mid
        |> Ash.Query.sort([{calculation, :asc_nils_last}, {:value, :asc}])
        |> Ash.read!(opts)
        |> Enum.map(& &1.id)
    end
  end

  @doc """
  Sorts inside a path: each root's mids ordered by their own leaf count, as a
  `first` aggregate or a relationship load. Root 1's mid 11 has two leaves and
  mid 12 one, so mid 11 comes first.
  """
  def sorted_cases, do: for(key <- @axes[:key], use <- [:first, :load], do: {key, use})

  def sorted_id({key, use}), do: "shape.sort_by_aggregate.#{key}.#{use}"

  def sorted_reference({_key, :first}), do: %{1 => 5, 2 => 3, 3 => 2, 4 => nil}

  def sorted_reference({key, :load}),
    do: %{1 => [key(key, 11), key(key, 12)], 2 => [key(key, 21)], 3 => [key(key, 31)], 4 => []}

  def sorted_run(adapter, {key, use}) do
    root = adapter.resource(:shape_root)
    opts = [authorize?: Ash.Conformance.Variant.authorize?()]

    case use do
      :first ->
        name = :"first_by_leaves_#{key}"
        root |> Ash.Query.load(name) |> Ash.read!(opts) |> Map.new(&{&1.id, Map.fetch!(&1, name)})

      :load ->
        name = :"#{key}_mids_by_leaves"

        root
        |> Ash.Query.load(name)
        |> Ash.read!(opts)
        |> Map.new(&{&1.id, Enum.map(Map.fetch!(&1, name), fn mid -> mid.id end)})
    end
  end
end
