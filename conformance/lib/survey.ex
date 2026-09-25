# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Survey do
  @moduledoc """
  Runs every scenario an adapter can host and classifies each result against
  the intended answer, without expectation records.

  This is how a data layer nobody has reviewed yet gets a feature report. The
  classification is automatic, so the report says so:

  - `works`: the intended answer, in every seed order;
  - `rejected`: an Ash error saying the feature is not supported;
  - `wrong`: a different value, or a value that changes with row order;
  - `crashed`: any other exception;
  - `open question`: the scenario awaits a semantic decision.

  A rejection is recognised only from Ash's error classes and wording, so it
  can misclassify. Review each result before recording expectations.
  """
  alias Ash.Conformance.{Catalog, FeatureReport, Report, Runner}

  @rejection ~r/does not support|not supported|unsupported|cannot be done|Cannot set/i

  def run(adapter) do
    adapter.setup!()

    for scenario <- Catalog.for_adapter(adapter), adapter.fixture?(scenario.fixture) do
      outcome = Runner.observe_both_orders(scenario, adapter)
      {classification, status} = classify(scenario, outcome)

      %{
        scenario: scenario.id,
        adapter: adapter.id(),
        status: status,
        classification: classification,
        task: nil,
        execution: :matched,
        expected: inspect(scenario.expected, limit: :infinity),
        actual: Report.outcome(outcome)
      }
    end
  end

  def classify(%{expected: :unresolved}, _outcome), do: {:open_question, :unresolved}

  def classify(scenario, outcome) do
    cond do
      Runner.semantic_pass?(scenario, outcome) -> {:works, :supported}
      rejection?(outcome) -> {:rejected, :unsupported}
      match?({:error, _, _}, outcome) -> {:crashed, :known_defect}
      true -> {:wrong, :known_defect}
    end
  end

  # An Ash error class whose message says the feature is unsupported, with no
  # nested exception from inside the data layer.
  defp rejection?({:error, exception, message})
       when exception in [Ash.Error.Invalid, Ash.Error.Unknown, Ash.Error.Forbidden] do
    Regex.match?(@rejection, message) and not String.contains?(message, "** (")
  end

  defp rejection?(_outcome), do: false

  def write!(adapter, rows, dir \\ Report.results_dir()) do
    File.mkdir_p!(dir)
    counts = Enum.frequencies_by(rows, & &1.classification)

    File.write!(
      Path.join(dir, "survey-#{adapter.id()}.json"),
      Jason.encode!(
        %{
          adapter: adapter.id(),
          dependency_set: Report.dependency_set(),
          unreviewed: true,
          counts: counts,
          scenarios: rows
        },
        pretty: true
      ) <> "\n"
    )

    File.write!(
      Path.join(dir, "features-#{adapter.id()}.md"),
      FeatureReport.markdown(rows, [adapter], :unreviewed)
    )

    counts
  end
end
