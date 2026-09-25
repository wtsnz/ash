# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Survey do
  @moduledoc """
  Classifies every scenario on one adapter, without expectations.

      MIX_ENV=test mix conformance.survey ets
      MIX_ENV=test mix conformance.survey ets --output surveys
      CONFORMANCE_DEPS=upstream MIX_ENV=test mix conformance.survey sqlite

  Writes `survey-ADAPTER.json` and an unreviewed `features-ADAPTER.md`.
  """
  use Mix.Task
  @shortdoc "Classify every scenario on one adapter, unreviewed"
  def run(args) do
    {opts, [name], _} = OptionParser.parse(args, strict: [output: :string])
    Mix.Task.run("app.start")
    adapter = Ash.Conformance.Adapter.find!(name)
    rows = Ash.Conformance.Survey.run(adapter)
    output = opts[:output] || Ash.Conformance.Report.results_dir()
    counts = Ash.Conformance.Survey.write!(adapter, rows, output)
    Mix.shell().info("Unreviewed #{name} survey: #{inspect(counts)}")
  end
end
