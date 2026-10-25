# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.EcosystemTest do
  use ExUnit.Case, async: false
  alias Ash.Conformance.Report.Ecosystem
  alias Ash.Conformance.Survey

  defmodule Minimal do
    @moduledoc false
    use Ash.Conformance.Adapter, id: :minimal, label: "Minimal", package: :ash
    def resource_config(_table), do: raise("not used")
    def setup!, do: :ok
  end

  defmodule Offline do
    @moduledoc false
    use Ash.Conformance.Adapter, id: :offline, label: "Offline", package: :ash
    def resource_config(_table), do: raise("not used")
    def setup!, do: raise("connection refused\nmore detail")
  end

  defmodule NoStorage do
    @moduledoc false
    use Ash.Conformance.Adapter, id: :no_storage, label: "NoStorage", package: :ash
    def resource_config(_table), do: raise("not used")
    def setup!, do: :ok
    def fixture?(fixture), do: fixture == :empty
    def checkout!, do: raise("no storage")
  end

  test "an adapter needs only its storage and resource configuration" do
    assert Minimal.resource(:record) == Module.concat(Minimal, Record)
    assert Minimal.expectations() == %{}
    assert Minimal.profiles() == [:shared]
    assert Minimal.fixture?(:records)
    refute Minimal.fixture?(:context_tenancy)
    assert Minimal.custom_aggregate() == Ash.Conformance.Resources.NoCustomAggregate
    assert Minimal.instrumentation() == nil
    assert Minimal.manual_relationship() == Ash.Conformance.Resources.PlainManual
    assert Minimal.identity_options() == []
  end

  test "the shared suite names no adapter; config registers the shipped ones" do
    shared =
      Path.wildcard("lib/**/*.ex") -- Path.wildcard("lib/{adapters,sql}/**/*.ex")

    for path <- shared, source = File.read!(path) do
      refute source =~ ~r/Ash\.Conformance\.(Sqlite|Postgres|Ets)\b|adapter\.id\(\) *==/,
             "#{path} refers to a specific adapter"
    end

    assert Ash.Conformance.Adapter.all() == Application.get_env(:ash_conformance, :adapters)
  end

  test "a data layer whose storage cannot start is reported as not run" do
    [result] = Ecosystem.run([Offline])
    assert result.unavailable == "connection refused"
    assert result.rows == []

    markdown = Ecosystem.markdown([result])
    assert markdown =~ "| offline | Offline |"
    assert markdown =~ "Not run: connection refused"
    assert markdown =~ "➖ Not run"
  end

  test "a fixture that cannot be stored is a setup failure, not a crash of the survey" do
    rows = Survey.run(NoStorage)
    assert rows != []
    assert Enum.all?(rows, &(&1.classification == :setup_failed))
    assert Enum.all?(rows, &String.contains?(&1.actual, "Setup failed: no storage"))
    assert Enum.all?(rows, &(&1.status == :unknown))

    markdown =
      Ecosystem.markdown([%{adapter: NoStorage, rows: rows, warnings: [], unavailable: nil}])

    assert markdown =~ "| #{length(rows)} | — | no storage |"
    refute markdown =~ "❌ Broken 0/"
    assert markdown =~ ~r/❔ Unknown \d+ not run/
  end

  defmodule RejectsFlags do
    @moduledoc false
    def persist!(:child, [%{visible: true}], _opts), do: raise("stored value could not be cast")
    def persist!(_role, _rows, _opts), do: :ok
    def resource(role), do: Ash.Conformance.Ets.resource(role)
  end

  test "seeding names the role, row, reason and storage cells of a row that cannot be stored" do
    error =
      assert_raise Ash.Conformance.Fixtures.SetupError, fn ->
        Ash.Conformance.Fixtures.seed!(RejectsFlags, :child, [
          %{id: 11, visible: false},
          %{id: 12, visible: true}
        ])
      end

    assert {error.role, error.row} == {:child, 12}
    # The storage cells the row depends on, so reports can name what blocked it.
    assert error.cells == ["storage.boolean.ordinary", "storage.integer.ordinary"]

    assert Exception.message(error) ==
             "Could not store child row 12: stored value could not be cast"
  end

  test "scenarios that never ran make a feature unknown or incomplete, never broken" do
    feature = %{scenarios: ["a", "b"]}
    alias Ash.Conformance.Contracts.Features

    assert Features.status(feature, [:unknown, :unknown]) == :unknown
    assert Features.status(feature, [:supported, :unknown]) == :incomplete
    assert Features.status(feature, [:known_defect, :unknown]) == :broken
    assert Features.status(feature, [:supported, :supported]) == :works

    summary = %{status: :incomplete, passing: 1, total: 1, unknown: 1}
    assert Ash.Conformance.Report.FeatureReport.cell(summary) == "🔸 Incomplete 1/1 · 1 not run"
  end
end
