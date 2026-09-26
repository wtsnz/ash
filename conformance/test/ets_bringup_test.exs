# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.EtsBringupTest do
  @moduledoc """
  Brings up Ash's ETS data layer through the probe path: no Ecto, no repository
  and no SQL. ETS has no expectation records, so every observation stays
  unreviewed and none counts as a semantic pass.
  """
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Adapter, Catalog, Probe}

  @matching ~w(loaded.count loaded.sum loaded.list root.count root.sum path.multi_hop
    path.many_to_many filter.exists bounds.relationship_limit use.keyset_pagination
    values.decimal_sum query.distinct query.union txn.commit generated.loaded.sum.lt_0)

  test "the ETS integration is probe-only and has no expectations" do
    refute Ash.Conformance.Ets in Adapter.all()
    assert Ash.DataLayer.data_layer(Ash.Conformance.Ets.resource(:parent)) == Ash.DataLayer.Ets
  end

  for id <- @matching do
    test "ETS observes the intended answer for #{id}, unreviewed" do
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(id)))
      report = Probe.run(scenario, Ash.Conformance.Ets)

      assert report.classification == :unreviewed
      assert report.semantic_pass == false
      assert report.observation.actual == Ash.Conformance.Report.value(scenario.expected)
    end
  end

  # ETS has no transactions, so the write survives. A probe shows that
  # difference without classifying it.
  test "a probe records a difference without judging it" do
    scenario = Enum.find(Catalog.all(), &(&1.id == "txn.raise_rollback"))
    report = Probe.run(scenario, Ash.Conformance.Ets)

    assert report.observation.actual == "{:raised, [2]}"
    assert report.semantic_pass == false
  end
end
