# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.CatalogTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Adapter, Capabilities, Catalog, Expectations, Gaps, Report}

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

          {:known_defect, signature, task} ->
            refute scenario.expected == :unresolved
            refute signature == {:value, scenario.expected}
            assert is_binary(task)

          {:unresolved, _signature, task} ->
            assert scenario.expected == :unresolved
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

  test "every gap has an owner that matches GAPS.md" do
    sections =
      File.read!("GAPS.md")
      |> String.split(~r/^## /m, trim: true)
      |> Enum.drop(1)
      |> Map.new(fn section ->
        [heading | body] = String.split(section, "\n")
        {heading |> String.downcase() |> String.replace(" ", "-"), Enum.join(body, "\n")}
      end)

    assert Enum.sort(Map.keys(sections)) == Enum.sort(Gaps.ids())

    for {id, body} <- sections do
      assert body =~ ~r/^#{Regex.escape(Gaps.owner_line(id))}$/m,
             "#{id} must state: #{Gaps.owner_line(id)}"

      assert Enum.uniq(Gaps.owners(id)) == Gaps.owners(id)

      case Gaps.kind(id) do
        :implementation -> :ok
        :decision -> assert body =~ "Decision:"
        :limitation -> assert body =~ "Limitation:"
      end
    end

    for %{task: task, owners: owners} <- Report.declaration_rows(), task do
      assert owners == task |> Gaps.id() |> Gaps.names()
    end
  end

  test "the checked-in matrix matches the executable declarations" do
    assert File.read!("MATRIX.md") == Report.matrix(), "Run mix conformance.matrix"
  end

  test "every scenario links to its declaration, including generated cases" do
    for scenario <- Catalog.all() do
      assert String.starts_with?(scenario.source.file, "lib/scenarios/")

      line =
        scenario.source.file
        |> File.read!()
        |> String.split("\n")
        |> Enum.at(scenario.source.line - 1)

      assert line =~ "new(", "#{scenario.id} source link must point to its declaration"

      assert Report.matrix() =~
               "[`#{scenario.id}`](#{scenario.source.file}#L#{scenario.source.line})"
    end
  end

  describe "feature catalog" do
    alias Ash.Conformance.{FeatureReport, Features}

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
          feature <- Features.all(),
          Enum.any?(
            feature.scenarios,
            &(&1 in Enum.map(Catalog.for_adapter(adapter), fn s -> s.id end))
          ),
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
