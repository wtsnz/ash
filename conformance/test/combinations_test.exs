# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.CombinationsTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Catalog, Combinations}

  defp answer(changes), do: Combinations.reference(Map.merge(Combinations.defaults(), changes))

  # Items (owner, tenant, value, status, seen_by): 11 (1, a, 5, open, 1),
  # 12 (1, b, 3, closed, 1), 13 (1, a, nil, open, 2), 14 (1, a, 1, closed, 1),
  # 15 (1, a, 6, open, 2), 21 (2, a, 4, open, 2), 22 (2, b, 7, open, 1),
  # 23 (2, a, 2, closed, 1). Links: owner 1 to 21 and 22, owner 2 to 11, 13
  # and 15, owner 3 to 12.
  test "single features, worked out by hand" do
    assert answer(%{}) == %{1 => 5, 2 => 3, 3 => 0}
    assert answer(%{kind: :sum}) == %{1 => 15, 2 => 13, 3 => nil}
    assert answer(%{kind: :list}) == %{1 => [5, 3, 1, 6], 2 => [4, 7, 2], 3 => []}
    assert answer(%{relationship: :top_items}) == %{1 => 2, 2 => 2, 3 => 0}
    assert answer(%{relationship: :linked_items}) == %{1 => 2, 2 => 3, 3 => 1}
    assert answer(%{tenant: :tenant}) == %{1 => 4, 2 => 2, 3 => 0}
    assert answer(%{policy: :actor}) == %{1 => 3, 2 => 2, 3 => 0}
    assert answer(%{filter: :open}) == %{1 => 3, 2 => 2, 3 => 0}
    assert answer(%{use: :page}) == {%{2 => 3, 3 => 0}, 3}
    assert answer(%{use: :sort}) == [1, 2, 3]
    assert answer(%{use: :filter}) == [1, 2]
  end

  test "tenant and policy apply before the limit, the aggregate filter after it" do
    # Owner 1 in tenant a, readable by user 1: 11 and 14; the top two are 11
    # (5) and 14 (1), and only 11 is above 2. Owner 2 keeps only 23 (2).
    changes = %{kind: :max, relationship: :top_items, filter: :value_gt}

    assert answer(Map.merge(changes, %{tenant: :tenant, policy: :actor})) == %{
             1 => 5,
             2 => nil,
             3 => nil
           }

    # Without them, owner 1's top two are 15 (6) and 11 (5).
    assert answer(changes) == %{1 => 6, 2 => 7, 3 => nil}
  end

  test "links, tenants and policies combine on the linked items" do
    changes = %{
      kind: :sum,
      relationship: :linked_items,
      filter: :open,
      tenant: :tenant,
      policy: :actor
    }

    assert answer(changes) == %{1 => nil, 2 => 5, 3 => nil}
  end

  test "sorting puts nils last and true before false" do
    assert answer(%{kind: :sum, use: :sort}) == [1, 2, 3]

    assert answer(%{kind: :exists, relationship: :linked_items, tenant: :tenant, use: :sort}) == [
             1,
             2,
             3
           ]

    assert answer(%{kind: :exists, tenant: :tenant, policy: :actor, use: :sort}) == [1, 2, 3]
    assert answer(%{kind: :max, relationship: :linked_items, use: :sort}) == [1, 2, 3]
  end

  test "every pair of axis values appears in some case, and ids are unique" do
    cases = Combinations.cases()
    ids = Enum.map(cases, &Combinations.scenario_id/1)
    assert ids == Enum.uniq(ids)

    for {a, a_values} <- Combinations.axes(),
        {b, b_values} <- Combinations.axes(),
        a < b,
        x <- a_values,
        y <- b_values,
        Combinations.valid?(%{a => x, b => y}) do
      assert Enum.any?(cases, &(&1[a] == x and &1[b] == y)), "#{a}=#{x} with #{b}=#{y}"
    end
  end

  test "a pairwise case requires the base and each of its features alone" do
    test_case =
      Map.merge(Combinations.defaults(), %{kind: :sum, tenant: :tenant, policy: :actor})

    assert Combinations.requires(test_case) ==
             ["combo.base", "combo.kind.sum", "combo.tenant.tenant", "combo.policy.actor"]

    assert :ok = Catalog.validate_requires!(Catalog.all())
  end

  test "every scenario has one tier, by its ID" do
    alias Ash.Conformance.Tiers

    assert Tiers.of("storage.decimal.edge") == :storage
    assert Tiers.of("ops.integer.sum") == :operations
    assert Tiers.of("policy.owner.read") == :policies
    assert Tiers.of("combo.base") == :combinations
    assert Tiers.of("loaded.count") == :integration

    tiers = Catalog.all() |> Enum.map(&Tiers.of(&1.id)) |> Enum.uniq() |> Enum.sort()
    assert tiers == Enum.sort(Keyword.keys(Tiers.all()))
  end
end
