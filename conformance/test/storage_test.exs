# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.StorageTest do
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Report.StorageGrid, Storage}

  test "every type has a scenario per class with values, and nil is always a class" do
    for type <- Storage.types() do
      assert :null in Storage.cells(type)
      assert :ordinary in Storage.cells(type)
      assert length(type.ordinary) >= 2, "#{type.name} needs two ordinary values to update"
    end
  end

  test "a table that cannot be created fails only its own type, with the reason" do
    Storage.provision(__MODULE__, fn
      %{name: :duration} -> raise "no duration column"
      _type -> {:ok, "text"}
    end)

    assert Storage.provisioned(__MODULE__, :duration) == {:error, "no duration column"}
    assert Storage.provisioned(__MODULE__, :integer) == {:ok, "text"}

    assert Storage.round_trip(__MODULE__, :duration, :ordinary) == [
             table: {:error, "no duration column"}
           ]
  end

  test "the grid separates unchanged, changed, lost, missing tables and unrun cells" do
    row = fn id, result ->
      %{
        scenario: id,
        classification: :wrong,
        detail: %{result: result, step: "read", note: "x", column: ":decimal"}
      }
    end

    rows = [
      row.("storage.decimal.ordinary", "ok"),
      row.("storage.decimal.edge", "changed"),
      row.("storage.decimal.null", "ok"),
      row.("storage.boolean.ordinary", "lost"),
      row.("storage.boolean.null", "ok"),
      row.("storage.map.ordinary", "no_table"),
      row.("storage.map.edge", "no_table"),
      row.("storage.map.null", "no_table"),
      %{scenario: "storage.integer.ordinary", classification: :setup_failed}
    ]

    markdown =
      StorageGrid.markdown([%{adapter: Ash.Conformance.Ets, rows: rows, unavailable: nil}])

    assert markdown =~ "| Decimals | ✅ ≈ ✅ |"
    assert markdown =~ "| Booleans | ❌ – ✅ |"
    assert markdown =~ "| Maps | 🚫 no table |"
    assert markdown =~ "| Integers | ❔ – – |"

    assert StorageGrid.detail(rows) =~ "| Decimals | `:decimal` | ✅ | ≈ | ✅ | edge, read: x |"
  end
end
