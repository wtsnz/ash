# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.FuzzTest do
  @moduledoc """
  A bounded, seeded run of generated filters on each selected reviewed
  adapter, against SQL's three-valued logic. A disagreement fails the build
  with the shrunk filter, to be triaged into a written scenario.
  """
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Adapter, Fuzz}

  @moduletag timeout: 300_000
  @opts [runs: 150, rounds: 2, seed: 2026]

  # Shrunk filters already triaged, with their gaps. Ash rewrites
  # `a in [0] and a in [1]` to false before any data layer sees it
  # (`in-simplification`).
  @known ["(a in [0] and a in [1])"]

  for adapter <- Adapter.selected() do
    test "generated filters follow SQL's three-valued logic on #{adapter.id()}" do
      adapter = unquote(adapter)
      failures = Fuzz.run(adapter, [setup?: false] ++ @opts)
      unknown = Enum.reject(failures, &(&1.filter in @known))
      assert unknown == [], Fuzz.markdown(adapter.label(), unknown, @opts)
    end
  end

  # Ash's own evaluator gets `nil and false` and `nil or false` wrong
  # (`runtime-nil-logic`). When Ash fixes it, this fails: update the gap.
  test "Ash's evaluation still differs from SQL's logic on a nil left operand" do
    Ash.Conformance.Ets.setup!()
    failures = Fuzz.runtime([adapter: Ash.Conformance.Ets] ++ @opts)

    assert failures != []
    assert Enum.all?(failures, &(&1.filter =~ ~r/ and | or /))
  end

  test "SQL's three-valued logic, worked out by hand" do
    resource = Ash.Conformance.Ets.resource(:expr_row)
    rows = Enum.map(Ash.Conformance.Fixtures.Expressions.rows(), &struct(resource, &1))

    # Row 3 has a nil `a` and a `b` of 4: nil and false is false.
    and_false = {:and, [{:compare, :a, :greater_than, 0}, {:compare, :b, :greater_than, 5}]}
    assert Fuzz.sql_keep(resource, rows, {:not, and_false}) == [1, 2, 3, 4]

    # nil or false is nil, so neither the filter nor its negation keeps row 3.
    or_false = {:or, [{:compare, :a, :greater_than, 0}, {:compare, :b, :greater_than, 5}]}
    assert Fuzz.sql_keep(resource, rows, or_false) == [1]
    assert Fuzz.sql_keep(resource, rows, {:not, or_false}) == [2]
  end

  test "a filter tree becomes a statement Ash parses, and a readable filter" do
    tree = {:not, {:or, [{:compare, :a, :greater_than, 1}, {:in, :s, ["x"]}]}}
    assert Fuzz.statement(tree) == [not: [or: [[a: [greater_than: 1]], [s: [in: ["x"]]]]]]
    assert Fuzz.describe(tree) == ~s|not (a > 1 or s in ["x"])|
  end
end
