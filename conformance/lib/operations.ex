# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Operations do
  @moduledoc """
  Tier 2: do Ash's filters, sorts and aggregates work on each type?

  Each type reuses its tier-1 resource and table. The fixture stores the
  type's operation values below, one per row with IDs from 1, then a row
  holding nil. Each operation that applies to the type runs on those rows,
  and the expected answer is computed from the values here:

  - `eq`: `value == ^first`, where `first` is row 1's value, or for
    case-insensitive strings the same value in another case;
  - `in`: `value in ^[first, second]`;
  - `is_nil`: `is_nil(value)`;
  - `gt`: `value > ^first` (ordered types; `first` is the middle value);
  - `sort`: `value` ascending with nils last, then `id`;
  - `count`: a root `count` of `value`, which counts non-nil values;
  - `min`, `max`: root aggregates (ordered types);
  - `sum`: a root aggregate (numeric types);
  - `first`: the first `value` by `id`.

  Values an aggregate returns are compared by the type's own equality, so a
  different representation, which tier 1 already reports, passes here.

  Integers are the control: every operation also runs on integers, and each
  cell requires its operation's integer cell and its type's storage cells
  (`requires:`). A failing cell whose control or storage also fails is
  blocked, not blamed on the operation.
  """
  alias Ash.Conformance.Storage

  # Row values in row order. Ordered types have three distinct values whose
  # row order is not their sorted order; the first is the middle value.
  @values %{
    integer: [2, 1, 3],
    float: [1.5, 0.5, 2.25],
    decimal: [Decimal.new("0.2"), Decimal.new("0.1"), Decimal.new("0.3")],
    string: ["banana", "apple", "cherry"],
    # Ash compares case-insensitive strings case-insensitively
    # (`Ash.CiString.compare/2`): apple < Banana < Cherry.
    ci_string: ["Banana", "apple", "Cherry"],
    binary: [<<2, 0>>, <<1, 0>>],
    boolean: [true, false],
    atom: [:green, :red],
    date: [~D[2024-02-29], ~D[1999-12-31], ~D[2024-03-01]],
    time: [~T[12:00:00], ~T[08:30:00], ~T[23:59:59]],
    time_usec: [~T[12:00:00.000001], ~T[12:00:00.000000], ~T[12:00:00.000002]],
    utc_datetime: [~U[2024-02-29 12:00:00Z], ~U[1999-12-31 23:59:59Z], ~U[2024-02-29 12:00:01Z]],
    utc_datetime_usec: [
      ~U[2024-02-29 12:00:00.000001Z],
      ~U[2024-02-29 12:00:00.000000Z],
      ~U[2024-02-29 12:00:00.000002Z]
    ],
    naive_datetime: [
      ~N[2024-02-29 12:00:00],
      ~N[1999-12-31 23:59:59],
      ~N[2024-02-29 12:00:01]
    ],
    duration: [Duration.new!(hour: 1), Duration.new!(minute: 30)],
    uuid: ["5f3c2a1e-8b7d-4c6e-9a0b-1c2d3e4f5a6b", "0b9e1d4c-2f3a-4b5c-8d6e-7f8091a2b3c4"],
    uuid_v7: ["01920d4e-6b1a-7c2d-8e3f-4a5b6c7d8e9f", "01920d4e-6b1b-7000-8000-000000000001"],
    map: [%{"a" => 1}, %{"b" => "x"}],
    strings: [["b", "a"], ["c"]],
    integers: [[3, 1], [4]],
    embedded: [%{city: "Auckland", zip: "1010"}, %{city: "Wellington", zip: "6011"}],
    embeddeds: [[%{city: "Auckland", zip: "1010"}], [%{city: "Dunedin", zip: "9016"}]],
    union: [%Ash.Union{type: :int, value: 5}, %Ash.Union{type: :text, value: "five"}]
  }

  @scalar ~w(integer float decimal string ci_string binary boolean atom date time time_usec
             utc_datetime utc_datetime_usec naive_datetime duration uuid uuid_v7)a
  @ordered ~w(integer float decimal string ci_string date time time_usec utc_datetime
              utc_datetime_usec naive_datetime)a
  @numeric ~w(integer float decimal)a

  @operations [
    eq: @scalar,
    in: @scalar,
    is_nil: :all,
    gt: @ordered,
    sort: @ordered,
    count: :all,
    min: @ordered,
    max: @ordered,
    sum: @numeric,
    first: :all
  ]

  def operations, do: Keyword.keys(@operations)

  @doc "Whether an operation applies to a type."
  def applies?(operation, name) do
    case Keyword.fetch!(@operations, operation) do
      :all -> true
      names -> name in names
    end
  end

  def values(name), do: Map.fetch!(@values, name)
  def scenario_id(name, operation), do: "ops.#{name}.#{operation}"

  @doc "The fixture's rows for a type: its values, then nil."
  def rows(name) do
    values = values(name)
    Enum.with_index(values ++ [nil], 1) |> Enum.map(fn {value, id} -> %{id: id, value: value} end)
  end

  @doc """
  What a cell builds on: the same operation on integers, and the type's
  ordinary and nil storage cells.
  """
  def requires(name, operation) do
    control = if name == :integer, do: [], else: [scenario_id(:integer, operation)]
    control ++ Storage.stored(name) ++ Storage.stored(name, :null)
  end

  @doc "The answer Ash defines for an operation on a type's rows."
  def expected(name, operation) do
    values = values(name)
    nil_id = length(values) + 1
    [first | _] = values

    case operation do
      :eq -> [1]
      :in -> [1, 2]
      :is_nil -> [nil_id]
      :gt -> ids(values, &(compare(name, &1, first) == :gt))
      :sort -> sorted_ids(name, values) ++ [nil_id]
      :count -> length(values)
      :min -> Enum.min(values, &(compare(name, &1, &2) != :gt))
      :max -> Enum.max(values, &(compare(name, &1, &2) != :lt))
      :sum -> sum(name, values)
      :first -> first
    end
  end

  defp ids(values, keep?) do
    values |> Enum.with_index(1) |> Enum.filter(&keep?.(elem(&1, 0))) |> Enum.map(&elem(&1, 1))
  end

  defp sorted_ids(name, values) do
    values
    |> Enum.with_index(1)
    |> Enum.sort(fn {a, _}, {b, _} -> compare(name, a, b) != :gt end)
    |> Enum.map(&elem(&1, 1))
  end

  defp sum(:decimal, values), do: Enum.reduce(values, &Decimal.add/2)
  defp sum(_name, values), do: Enum.sum(values)

  defp compare(:ci_string, a, b), do: Ash.CiString.compare(a, b)
  defp compare(:decimal, a, b), do: Decimal.compare(a, b)
  defp compare(name, a, b) when name in [:date, :time, :time_usec], do: a.__struct__.compare(a, b)

  defp compare(name, a, b) when name in [:utc_datetime, :utc_datetime_usec],
    do: DateTime.compare(a, b)

  defp compare(:naive_datetime, a, b), do: NaiveDateTime.compare(a, b)

  defp compare(_name, a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  @doc "Runs one cell on the type's resource."
  def run(adapter, name, operation) do
    resource = adapter.resource(Storage.role(name))
    values = values(name)

    case operation do
      :eq ->
        filter_ids(resource, name, :eq, probe(name, hd(values)))

      :in ->
        filter_ids(resource, name, :in, Enum.take(values, 2))

      :is_nil ->
        filter_ids(resource, name, :is_nil, nil)

      :gt ->
        filter_ids(resource, name, :gt, hd(values))

      :sort ->
        sorted(resource)

      :count ->
        aggregate(resource, :count)

      kind when kind in [:min, :max, :sum] ->
        same(resource, name, kind, aggregate(resource, kind))

      :first ->
        same(resource, name, :first, aggregate(resource, :first, query: [sort: [id: :asc]]))
    end
  end

  defp probe(:ci_string, value), do: String.upcase(value)
  defp probe(_name, value), do: value

  # In each filter, `value` is the attribute and `^probe` the operand.
  defp filter_ids(resource, _name, kind, probe) do
    require Ash.Query

    query =
      case kind do
        :eq -> Ash.Query.filter(resource, value == ^probe)
        :in -> Ash.Query.filter(resource, value in ^probe)
        :is_nil -> Ash.Query.filter(resource, is_nil(value))
        :gt -> Ash.Query.filter(resource, value > ^probe)
      end

    query |> Ash.read!(authorize?: false) |> Enum.map(& &1.id) |> Enum.sort()
  end

  defp sorted(resource) do
    resource
    |> Ash.Query.sort(value: :asc_nils_last, id: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp aggregate(resource, kind, opts \\ []) do
    resource
    |> Ash.aggregate!([{:result, kind, [field: :value] ++ opts}], authorize?: false)
    |> Map.fetch!(:result)
  end

  # The expected value when the type considers them equal, so a failure shows
  # what came back and a pass does not depend on representation.
  defp same(resource, name, operation, got) do
    want = expected(name, operation)
    attribute = Ash.Resource.Info.attribute(resource, :value)
    if Storage.same?(attribute, want, got), do: want, else: got
  end
end
