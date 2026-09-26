# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.CatalogTest do
  use ExUnit.Case, async: true

  alias Ash.Conformance.{
    Adapter,
    Catalog,
    Contracts.Capabilities,
    Contracts.Expectations,
    Contracts.Gaps,
    Report
  }

  test "every unique scenario has exactly one explicit status per adapter" do
    ids = Enum.map(Catalog.all(), & &1.id)
    assert length(ids) == length(Enum.uniq(ids))
    assert Enum.sort(ids) == Enum.sort(Map.keys(Expectations.all()))

    for scenario <- Catalog.all() do
      statuses = Map.fetch!(Expectations.all(), scenario.id)

      adapters =
        Adapter.all()
        |> Enum.filter(&(scenario.profile in &1.profiles()))
        |> Enum.map(& &1.id())
        |> Enum.sort()

      assert Enum.sort(Map.keys(statuses)) == adapters

      for {_adapter, expectation} <- statuses do
        case expectation do
          :supported ->
            refute scenario.expected == :unresolved

          {:unsupported, {:error, exception, %Regex{}}, task} ->
            refute scenario.expected == :unresolved
            assert is_atom(exception) and is_binary(task)

          # A rejection captured inside a step-by-step observation.
          {:unsupported, {:value, value}, task} ->
            refute scenario.expected == :unresolved
            refute value == scenario.expected
            assert is_binary(task)

          {:known_defect, signature, task} ->
            refute scenario.expected == :unresolved
            refute signature == {:value, scenario.expected}
            assert is_binary(task)

          {:unresolved, _signature, task} ->
            assert scenario.expected == :unresolved
            assert is_binary(task)

          # A fixture the data layer cannot store: only a setup failure matches.
          {:unknown, {:setup_error, %Regex{}}, task} ->
            refute scenario.expected == :unresolved
            assert is_binary(task)
        end
      end
    end
  end

  test "missing scenarios and adapters cannot silently default to supported" do
    assert_raise KeyError, fn -> Expectations.for("missing", :sqlite) end
    assert_raise KeyError, fn -> Expectations.for("loaded.count", :missing) end
  end

  test "gap links resolve to a decision or implementation task" do
    headings =
      File.read!("GAPS.md")
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "## "))
      |> Enum.map(fn heading ->
        heading |> String.trim_leading("## ") |> String.downcase() |> String.replace(" ", "-")
      end)

    for %{task: task} <- Report.declaration_rows(), not is_nil(task) do
      assert "GAPS.md#" <> anchor = task
      assert anchor in headings, "Missing task: #{task}"
    end
  end

  test "GAPS.md is rendered from the gaps where their knowledge lives" do
    assert File.read!("GAPS.md") == Gaps.markdown(), "Run MIX_ENV=test mix conformance.gaps"

    # Gaps.all/0 raises unless IDs are unique, titles match their anchors,
    # owners are distinct, and decisions and limitations say so.
    assert Gaps.all() != []

    for id <- Gaps.ids() do
      assert File.read!("GAPS.md") =~ ~r/^#{Regex.escape(Gaps.owner_line(id))}$/m
    end
  end

  test "gaps an adapter records must exist, and every gap is used or is shared" do
    linked =
      for {_id, statuses} <- Expectations.all(),
          {_adapter, {_status, _signature, "GAPS.md#" <> gap}} <- statuses,
          into: MapSet.new(),
          do: gap

    shared = Enum.map(Ash.Conformance.Contracts.SharedGaps.all(), & &1.id)

    for id <- Gaps.ids(), id not in shared do
      assert id in linked, "#{id} is documented but no expectation links to it"
    end
  end

  test "the checked-in matrix matches the executable declarations" do
    assert File.read!("MATRIX.md") == Report.matrix(), "Run mix conformance.matrix"
  end

  test "every scenario links to its declaration, including generated cases" do
    matrix = Report.matrix()

    for scenario <- Catalog.all() do
      assert String.starts_with?(scenario.source.file, "lib/scenarios/")

      declaration =
        scenario.source.file
        |> File.read!()
        |> String.split("\n")
        |> Enum.slice(scenario.source.line - 1, 3)
        |> Enum.join("\n")

      # The declaration names the scenario, unless its ID is generated in a loop.
      assert declaration =~ ~s("#{scenario.id}") or declaration =~ ~r/^\s*new\(".*#\{/m,
             "#{scenario.id} source link must point to its declaration:\n#{declaration}"

      assert matrix =~
               "[`#{scenario.id}`](#{scenario.source.file}#L#{scenario.source.line})"
    end
  end

  describe "feature catalog" do
    alias Ash.Conformance.{Contracts.Features, Report.FeatureReport}

    test "every scenario belongs to exactly one feature, and every listed scenario exists" do
      listed = Enum.flat_map(Features.all(), & &1.scenarios)
      ids = Enum.map(Catalog.all(), & &1.id)

      assert Enum.sort(listed) == Enum.sort(ids),
             "unlisted: #{inspect(ids -- listed)}; unknown or repeated: #{inspect(listed -- ids)}"

      feature_ids = Enum.map(Features.all(), & &1.id)
      assert length(feature_ids) == length(Enum.uniq(feature_ids))
    end

    test "every claim resolves on every adapter that runs the feature" do
      for adapter <- Adapter.all(),
          ids = MapSet.new(Catalog.for_adapter(adapter), & &1.id),
          feature <- Features.all(),
          Enum.any?(feature.scenarios, &MapSet.member?(ids, &1)),
          {role, claim} <- feature.claims do
        assert is_boolean(Capabilities.probe(adapter, role, claim).advertised)
      end
    end

    test "a feature's status follows its scenarios" do
      feature = %{scenarios: ["a"]}
      assert Features.status(%{scenarios: []}, []) == :untested
      assert Features.status(feature, []) == :not_applicable
      assert Features.status(feature, [:supported, :supported]) == :works
      assert Features.status(feature, [:supported, :unsupported]) == :partial
      assert Features.status(feature, [:supported, :known_defect]) == :partial
      assert Features.status(feature, [:unsupported, :unsupported]) == :not_supported
      assert Features.status(feature, [:unsupported, :known_defect]) == :broken
      assert Features.status(feature, [:supported, :unresolved]) == :open_question
    end

    test "a failed check marks its feature as changed" do
      feature = %{scenarios: ["a", "b"]}

      rows = [
        %{scenario: "a", status: :supported, task: nil, execution: :matched},
        %{scenario: "b", status: :supported, task: nil, execution: :failed}
      ]

      assert FeatureReport.summarize(feature, rows).status == :changed
    end

    test "the checked-in feature report matches the declared contracts" do
      assert File.read!("FEATURES.md") == FeatureReport.declared(), "Run mix conformance.features"
    end
  end
end
