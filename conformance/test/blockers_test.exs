# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.BlockersTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Blockers, Catalog, Scenario, Storage}

  defp row(id, classification, extra \\ %{}),
    do: Map.merge(%{scenario: id, classification: classification, actual: "x"}, extra)

  defp storage(id, result),
    do: row(id, :wrong, %{detail: %{result: result, step: "read", note: "n"}})

  defp blocked(rows, requires \\ %{}),
    do: rows |> Blockers.label(requires) |> Map.new(&{&1.scenario, &1.blocked_by})

  test "a failure is blocked by a failing prerequisite; a pass never is" do
    rows = [row("control", :crashed), row("a", :wrong), row("b", :works)]
    requires = %{"a" => ["control"], "b" => ["control"]}

    assert blocked(rows, requires) == %{"control" => [], "a" => ["control"], "b" => []}
  end

  test "a working prerequisite, or an open question, blocks nothing" do
    rows = [row("control", :works), row("question", :open_question), row("a", :wrong)]

    assert blocked(rows, %{"a" => ["control", "question"]})["a"] == []
  end

  test "a blocked prerequisite passes on its own blockers, so reports name the root" do
    rows = [
      storage("storage.decimal.edge", "lost"),
      row("values.decimal_read_control", :wrong),
      row("values.decimal_sum", :wrong)
    ]

    requires = %{
      "values.decimal_read_control" => ["storage.decimal.edge"],
      "values.decimal_sum" => ["values.decimal_read_control"]
    }

    assert blocked(rows, requires)["values.decimal_sum"] == ["storage.decimal.edge"]
  end

  test "a declared storage cell blocks only when its value is lost or rejected" do
    # A missing table shows the generator's gap, not whether the type stores.
    for {result, blocks?} <- [
          {"lost", true},
          {"error", true},
          {"no_table", false},
          {"changed", false},
          {"order_dependent", false},
          {"ok", false}
        ] do
      rows = [storage("storage.map.ordinary", result), row("a", :wrong)]
      expected = if blocks?, do: ["storage.map.ordinary"], else: []

      assert blocked(rows, %{"a" => ["storage.map.ordinary"]})["a"] == expected, result
    end
  end

  test "a declared storage cell that fails only when updated or cleared blocks nothing" do
    # Scenarios read what their fixtures stored, as with Ash's union-nil bug,
    # which only shows when a union is set to nil.
    for step <- ["update", "clear"] do
      rows = [
        row("storage.union.ordinary", :wrong, %{detail: %{result: "lost", step: step, note: "n"}}),
        row("a", :wrong)
      ]

      assert blocked(rows, %{"a" => ["storage.union.ordinary"]})["a"] == [], step
    end
  end

  test "a setup failure is blocked by the failing storage cells of its row's types" do
    setup = %{
      role: "child",
      reason: "cannot cast",
      cells: ~w(storage.boolean.ordinary storage.integer.ordinary)
    }

    rows = [
      storage("storage.boolean.ordinary", "error"),
      row("storage.integer.ordinary", :works, %{detail: %{result: "ok", step: nil, note: nil}}),
      row("a", :setup_failed, %{setup: setup})
    ]

    assert blocked(rows)["a"] == ["storage.boolean.ordinary"]
  end

  test "only a cell that raised on store or read explains a setup failure" do
    # A setup failure is an exception: a lost value or a missing generator
    # table cannot have caused it.
    for {result, step, explains?} <- [
          {"error", "create", true},
          {"error", "read", true},
          {"error", "update", false},
          {"lost", "read", false},
          {"no_table", "table", false}
        ] do
      rows = [
        row("storage.uuid.ordinary", :wrong, %{detail: %{result: result, step: step, note: "n"}}),
        row("a", :setup_failed, %{
          setup: %{role: "r", reason: "?", cells: ["storage.uuid.ordinary"]}
        })
      ]

      expected = if explains?, do: ["storage.uuid.ordinary"], else: []
      assert blocked(rows)["a"] == expected, "#{result} at #{step}"
    end
  end

  test "a setup failure counts only its row's cells; a prerequisite that never ran is not a cause" do
    setup = %{role: "r", reason: "?", cells: []}

    rows = [
      storage("storage.date.ordinary", "lost"),
      row("control", :setup_failed, %{setup: setup}),
      row("a", :setup_failed, %{setup: setup}),
      row("b", :wrong)
    ]

    requires = %{"a" => ["storage.date.ordinary"], "b" => ["control"]}

    assert blocked(rows, requires) == %{
             "storage.date.ordinary" => [],
             "control" => [],
             "a" => [],
             "b" => []
           }
  end

  test "a setup failure no storage cell explains is listed as unexplained" do
    setup = %{role: "record", reason: "no encoder", cells: ["storage.integer.ordinary"]}

    rows =
      Blockers.label(
        [
          row("storage.integer.ordinary", :works, %{detail: %{result: "ok", step: nil, note: nil}}),
          row("a", :setup_failed, %{setup: setup}),
          row("b", :setup_failed, %{setup: setup})
        ],
        %{}
      )

    assert Blockers.unexplained(rows) == [{{"record", "no encoder"}, 2}]
    assert Blockers.markdown(rows) =~ "| 2 | `record` | no encoder |"
  end

  test "blockers are ranked by scenarios affected, then by those they alone block" do
    cells = fn ids -> %{setup: %{role: "r", reason: "?", cells: ids}} end

    rows = [
      row("x", :wrong),
      storage("storage.map.ordinary", "error"),
      storage("storage.float.ordinary", "error"),
      row("a", :setup_failed, cells.(["storage.map.ordinary"])),
      row("b", :setup_failed, cells.(["storage.float.ordinary", "storage.map.ordinary"])),
      row("c", :wrong)
    ]

    ranking = rows |> Blockers.label(%{"c" => ["x"]}) |> Blockers.ranking()

    assert ranking == [
             %{blocker: "storage.map.ordinary", not_run: 2, failing: 0, only: 1},
             %{blocker: "x", not_run: 0, failing: 1, only: 1},
             %{blocker: "storage.float.ordinary", not_run: 1, failing: 0, only: 0}
           ]
  end

  test "a value maps to its type's ordinary cell, or the null cell for nil" do
    attribute = fn type -> %{type: Ash.Type.get_type(type), constraints: []} end

    assert Storage.cell(attribute.(:boolean), true) == "storage.boolean.ordinary"
    assert Storage.cell(attribute.(:decimal), nil) == "storage.decimal.null"
    assert Storage.cell(attribute.({:array, :string}), ["a"]) == "storage.strings.ordinary"

    assert Storage.cell(attribute.(Ash.Conformance.Resources.Address), %{}) ==
             "storage.embedded.ordinary"

    assert Storage.cell(attribute.(Ash.Type.Term), 1) == nil
  end

  test "prerequisites must name scenarios and must not form a cycle" do
    scenario = fn id, requires ->
      %Scenario{id: id, area: :x, expected: 1, run: & &1, requires: requires}
    end

    assert :ok = Catalog.validate_requires!(Catalog.all())

    assert_raise ArgumentError, ~r/requires unknown scenario missing/, fn ->
      Catalog.validate_requires!([scenario.("a", ["missing"])])
    end

    assert_raise ArgumentError, ~r/cycle/, fn ->
      Catalog.validate_requires!([scenario.("a", ["b"]), scenario.("b", ["a"])])
    end
  end

  test "every policy cell requires its path's control" do
    for %{id: "policy." <> rest} = scenario <- Catalog.all(),
        not String.starts_with?(rest, "control.") do
      [_case, path] = String.split(rest, ".", parts: 2)
      assert scenario.requires == ["policy.control.#{path}"], scenario.id
    end
  end
end
