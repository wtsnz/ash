# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.SurveyComparison do
  @moduledoc "Feature and scenario changes between two surveys of one adapter."
  alias Ash.Conformance.{Contracts.Features, Report.FeatureReport}

  def markdown(base, current) do
    base_rows = rows(base)
    current_rows = rows(current)

    features =
      for feature <- Features.all(),
          before = FeatureReport.summarize(feature, base_rows),
          now = FeatureReport.summarize(feature, current_rows),
          {before.status, before.passing} != {now.status, now.passing} do
        "| #{feature.title} | #{describe(before)} | #{describe(now)} |"
      end

    base_index = Map.new(base_rows, &{&1.scenario, &1.classification})

    scenarios =
      for row <- Enum.sort_by(current_rows, & &1.scenario),
          before = Map.get(base_index, row.scenario, :not_run),
          before != row.classification do
        "| `#{row.scenario}` | #{before} | #{row.classification} |"
      end

    """
    ## #{current["adapter"]}: #{base["dependency_set"]} → #{current["dependency_set"]}

    #{length(features)} features and #{length(scenarios)} scenarios changed.

    | Feature | #{base["dependency_set"]} | #{current["dependency_set"]} |
    | --- | --- | --- |
    #{Enum.join(features, "\n")}

    | Scenario | #{base["dependency_set"]} | #{current["dependency_set"]} |
    | --- | --- | --- |
    #{Enum.join(scenarios, "\n")}
    """
  end

  defp rows(survey) do
    Enum.map(survey["scenarios"], fn row ->
      %{
        scenario: row["scenario"],
        adapter: String.to_atom(row["adapter"]),
        status: known!(row["status"], ~w(supported unsupported known_defect unresolved unknown)a),
        classification:
          known!(
            row["classification"],
            ~w(works rejected wrong crashed setup_failed open_question)a
          ),
        task: nil,
        execution: :matched
      }
    end)
  end

  defp known!(value, allowed) do
    Enum.find(allowed, &(Atom.to_string(&1) == value)) ||
      raise ArgumentError, "Unknown survey value: #{inspect(value)}"
  end

  defp describe(summary), do: FeatureReport.cell(summary)
end
