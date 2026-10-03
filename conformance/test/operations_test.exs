# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.OperationsTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Blockers, Catalog, Operations, Storage}

  test "expected answers, worked out by hand" do
    # Integers: rows 1..3 hold 2, 1, 3; row 4 is nil.
    assert Operations.expected(:integer, :eq) == [1]
    assert Operations.expected(:integer, :in) == [1, 2]
    assert Operations.expected(:integer, :is_nil) == [4]
    assert Operations.expected(:integer, :gt) == [3]
    assert Operations.expected(:integer, :sort) == [2, 1, 3, 4]
    assert Operations.expected(:integer, :count) == 3
    assert {Operations.expected(:integer, :min), Operations.expected(:integer, :max)} == {1, 3}
    assert Operations.expected(:integer, :sum) == 6
    assert Operations.expected(:integer, :first) == 2

    # Case-insensitive strings: Banana, apple, Cherry sort as apple, Banana, Cherry.
    assert Operations.expected(:ci_string, :sort) == [2, 1, 3, 4]
    assert Operations.expected(:ci_string, :min) == "apple"

    # Microseconds decide the order.
    assert Operations.expected(:utc_datetime_usec, :sort) == [2, 1, 3, 4]
    assert Operations.expected(:decimal, :sum) == Decimal.new("0.6")
    assert Operations.expected(:float, :sum) == 4.25
    assert Operations.expected(:map, :is_nil) == [3]
  end

  test "ordered types list their middle value first and not in sorted order" do
    for type <- Storage.types(), Operations.applies?(:sort, type.name) do
      assert length(Operations.values(type.name)) == 3, "#{type.name} needs three values"
      assert Operations.expected(type.name, :sort) == [2, 1, 3, 4], "#{type.name}"
    end
  end

  test "every type has operation values, and every cell requires its integer control" do
    for type <- Storage.types() do
      assert length(Operations.values(type.name)) >= 2

      for operation <- Operations.operations(), Operations.applies?(operation, type.name) do
        requires = Operations.requires(type.name, operation)
        assert "storage.#{type.name}.ordinary" in requires
        assert type.name == :integer or "ops.integer.#{operation}" in requires
      end
    end

    assert :ok = Catalog.validate_requires!(Catalog.all())
  end

  test "a missing tier-1 table blocks tier 2, whose rows go into that table" do
    setup = %{role: "storage_map", reason: "no table", cells: ["storage.map.ordinary"]}
    no_table = %{result: "no_table", step: "table", note: "n"}

    rows = fn own_table? ->
      [
        %{scenario: "storage.map.ordinary", classification: :wrong, detail: no_table},
        %{
          scenario: "ops.map.count",
          classification: :setup_failed,
          actual: "x",
          setup: Map.put(setup, :own_table, own_table?)
        }
      ]
    end

    blocked = fn own_table? ->
      own_table? |> rows.() |> Blockers.label(%{}) |> List.last() |> Map.fetch!(:blocked_by)
    end

    assert blocked.(true) == ["storage.map.ordinary"]
    # A shared fixture's table is built by the suite, so the generator's gap
    # does not explain it.
    assert blocked.(false) == []
  end
end
