# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.RecordsTest do
  use ExUnit.Case, async: true
  import Ash.Conformance.Contracts.Records

  @sqlite Ash.Conformance.Sqlite
  @rejection unsupported(~r/no error expressions/, "error-expressions")

  test "a wildcard supports everything no expect rule claims" do
    records = resolve(@sqlite, [supported("*"), expect("policy.*.get_error", @rejection)])

    assert {:unsupported, {:error, Ash.Error.Unknown, pattern}, "GAPS.md#error-expressions"} =
             records["policy.owner.get_error"]

    assert Regex.source(pattern) == "no error expressions"
    assert records["policy.owner.read"] == :supported
    assert map_size(records) == length(Ash.Conformance.Catalog.for_adapter(@sqlite))
  end

  test "a scenario no rule covers has no record, so validation rejects it" do
    records = resolve(@sqlite, [supported("policy.*")])
    refute Map.has_key?(records, "loaded.count")
  end

  test "two expect rules for one scenario, or a rule matching nothing, raise" do
    assert_raise ArgumentError, ~r/matches several expectation rules/, fn ->
      resolve(@sqlite, [expect("policy.owner.*", @rejection), expect("policy.*.read", @rejection)])
    end

    assert_raise ArgumentError, ~r/matches no scenario/, fn ->
      resolve(@sqlite, [supported("*"), expect("policy.nobody.read", @rejection)])
    end
  end
end
