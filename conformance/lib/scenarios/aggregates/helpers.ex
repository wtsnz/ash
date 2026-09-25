# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Helpers do
  @moduledoc false
  require Ash.Query

  def loaded(context, kind, path \\ :children, opts \\ [], read_opts \\ []) do
    context.parent
    |> Ash.Query.build(aggregate: {:result, kind, path, opts})
    |> Ash.Query.sort(:id)
    |> Ash.read!(Keyword.put_new(read_opts, :authorize?, false))
    |> Map.new(&{&1.id, normalize(Map.fetch!(&1.aggregates, :result))})
  end

  @doc "Like `loaded/5`, but compares decimals exactly instead of as rounded floats."
  def loaded_exact(context, kind, path, opts) do
    context.parent
    |> Ash.Query.build(aggregate: {:result, kind, path, opts})
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, exact(Map.fetch!(&1.aggregates, :result))})
  end

  def exact(%Decimal{} = value), do: value |> Decimal.normalize() |> Decimal.to_string(:normal)
  def exact(value) when is_list(value), do: Enum.map(value, &exact/1)
  def exact(value), do: value

  def root(context, kind, opts \\ []) do
    Ash.aggregate!(context.child, [{:result, kind, opts}], authorize?: false)
    |> Map.fetch!(:result)
    |> normalize()
  end

  def named(context, name, read_opts \\ []) do
    context.parent
    |> Ash.Query.load(name)
    |> Ash.read!(Keyword.put_new(read_opts, :authorize?, false))
    |> Map.new(&{&1.id, Map.fetch!(&1, name)})
  end

  def relationship_ids(context, name, read_opts \\ []) do
    context.parent
    |> Ash.Query.load(name)
    |> Ash.read!(Keyword.put_new(read_opts, :authorize?, false))
    |> Map.new(fn row ->
      ids = row |> Map.fetch!(name) |> List.wrap() |> Enum.map(& &1.id) |> Enum.sort()
      {row.id, ids}
    end)
  end

  def selected_parent(context, id \\ 1), do: Ash.Query.filter(context.parent, id == ^id)

  def normalize(%Decimal{} = value), do: value |> Decimal.to_float() |> Float.round(6)
  def normalize(value) when is_float(value), do: Float.round(value, 6)
  def normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  def normalize(value), do: value
end
