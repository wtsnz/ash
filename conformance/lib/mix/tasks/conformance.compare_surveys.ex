# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.CompareSurveys do
  @moduledoc """
  Compares two surveys of the same adapter, for example ash-project main
  against the unreleased work:

      CONFORMANCE_DEPS=upstream MIX_ENV=test mix conformance.survey sqlite
      MIX_ENV=test mix conformance.survey sqlite
      MIX_ENV=test mix conformance.compare_surveys \\
        results/upstream/survey-sqlite.json results/survey-sqlite.json

  Prints which features and scenarios changed classification, and writes the
  same Markdown next to the current survey.
  """
  use Mix.Task
  @shortdoc "Compare two surveys feature by feature"
  def run([base, current]) do
    Mix.Task.run("compile")
    markdown = Ash.Conformance.Report.SurveyComparison.markdown(read!(base), read!(current))
    output = Path.join(Path.dirname(current), "compare-#{Path.basename(current, ".json")}.md")
    File.write!(output, markdown)
    Mix.shell().info(markdown)
  end

  defp read!(path), do: path |> File.read!() |> Jason.decode!()
end
