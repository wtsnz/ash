# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.ContractTest do
  use ExUnit.Case, async: false

  alias Ash.Conformance.{
    Adapter,
    Catalog,
    Contracts.Capabilities,
    Contracts.Expectations,
    Report,
    Report.Inventory,
    Runner
  }

  test "all dependencies use the parent Ash checkout" do
    assert Mix.Project.deps_paths()[:ash] == Path.expand("..")
  end

  test "duplicate IDs and incomplete expectations cannot enter the registry" do
    [scenario | _] = Catalog.all()

    assert_raise ArgumentError, ~r/Duplicate/, fn ->
      Catalog.validate!([scenario, scenario], Expectations.all(), Adapter.all())
    end

    assert_raise ArgumentError, ~r/Missing or stale/, fn ->
      Catalog.validate!(Catalog.all(), Map.delete(Expectations.all(), scenario.id), Adapter.all())
    end

    bad = put_in(Expectations.all(), ["loaded.count"], %{})
    assert_raise KeyError, fn -> Catalog.validate!(Catalog.all(), bad, Adapter.all()) end
    assert :ok = Catalog.validate!(Catalog.all(), Expectations.all(), Adapter.all())
  end

  test "fixture exceptions cannot match an expected operation defect" do
    scenario = Enum.find(Catalog.all(), &(&1.id == "loaded.count"))

    expectation =
      {:known_defect, {:error, ArgumentError, ~r/^fixture failed$/}, "GAPS.md#example"}

    assert_raise ArgumentError, "fixture failed", fn ->
      Runner.run_with_setup!(scenario, expectation, fn ->
        raise ArgumentError, "fixture failed"
      end)
    end
  end

  test "reported claims use the requested resource and aggregate kind" do
    sqlite = Ash.Conformance.Sqlite

    assert %{advertised: true, role: :parent} =
             Capabilities.probe(sqlite, :parent, {:aggregate, :list})

    assert %{advertised: false, role: :child} =
             Capabilities.probe(sqlite, :child, {:query_aggregate, :list})

    row =
      Enum.find(
        Report.declaration_rows(),
        &(&1.scenario == "root.list" and &1.adapter == :sqlite)
      )

    assert %{advertised: false, resource: "Ash.Conformance.Sqlite.Child"} =
             Enum.find(row.capabilities, &(&1.feature == "{:query_aggregate, :list}"))

    assert row.status == :unsupported
    assert row.fallback == :unobserved
    assert Report.verdict(Map.put(row, :execution, :matched)) == "GAP MATCHED"
    assert Report.verdict(Map.merge(row, %{status: :supported, execution: :failed})) == "FAILED"
  end

  test "planned areas and unavailable profiles never become passes" do
    inventory = Inventory.document()

    assert Enum.any?(
             inventory.features,
             &(&1.id == "pagination.concurrent" and &1.status == :planned)
           )

    # A planned feature has no scenario, so it can only ever report untested.
    for %{status: :planned} = feature <- inventory.features do
      assert feature.scenarios == []

      assert Ash.Conformance.Report.FeatureReport.summarize(%{scenarios: []}, []).status ==
               :untested
    end

    refute Enum.any?(
             Catalog.for_adapter(Ash.Conformance.Sqlite),
             &(&1.profile == :context_tenancy)
           )

    refute Enum.any?(
             Report.declaration_rows(),
             &(&1.adapter == :sqlite and &1.profile == :context_tenancy)
           )

    assert File.read!("COVERAGE.md") == Inventory.markdown()
    assert File.read!("CAPABILITIES.md") == Capabilities.markdown()
  end

  test "SQLite's transaction claim follows the repo setting the suite configures" do
    assert Ash.Conformance.SqliteRepo.write_transactions?()
    assert Capabilities.probe(Ash.Conformance.Sqlite, :ledger, :transact).advertised
  end

  for adapter <- Adapter.selected() do
    test "#{adapter.id()} query callback returns records and claims are booleans" do
      adapter = unquote(adapter)
      :ok = adapter.checkout!()

      try do
        context = Ash.Conformance.Fixtures.Aggregate.seed!(adapter)
        query = Ash.DataLayer.resource_to_query(context.parent, Ash.Conformance.Resources.Domain)
        assert {:ok, query} = Ash.DataLayer.set_context(context.parent, query, %{})
        assert {:ok, rows} = Ash.DataLayer.run_query(query, context.parent)
        assert Enum.sort(Enum.map(rows, & &1.id)) == [1, 2, 3]
        assert Enum.all?(Capabilities.matrix(adapter), &is_boolean(&1.advertised))
        callbacks = Capabilities.callbacks(adapter)
        assert Enum.all?(Enum.reject(callbacks, & &1.optional), & &1.exported)
      after
        adapter.checkin!()
      end
    end
  end

  defmodule ExternalAdapter do
    @moduledoc false
    use Ash.Conformance.Adapter, id: :external, label: "External", package: :ash
    def expectations, do: %{"record.read_all" => :supported}
    def identity_options, do: [pre_check?: true]
    def resource_config(_table), do: raise("not used")
    def setup!, do: :ok
  end

  describe "adapters from other repositories" do
    setup do
      shipped = Adapter.all()
      on_exit(fn -> Application.put_env(:ash_conformance, :adapters, shipped) end)
    end

    test "join through config, with their own expectations, without editing shared code" do
      Application.put_env(:ash_conformance, :adapters, Adapter.all() ++ [ExternalAdapter])

      assert ExternalAdapter in Adapter.all()
      assert Expectations.for("record.read_all", :external) == :supported
      assert Expectations.for("record.read_all", :sqlite) == :supported
    end

    test "can ask for identities to be pre-checked" do
      assert Ash.Conformance.Resources.Base.identity_options(ExternalAdapter) == [
               pre_check?: true
             ]

      assert Ash.Conformance.Resources.Base.identity_options(Ash.Conformance.Postgres) == []
    end
  end
end
