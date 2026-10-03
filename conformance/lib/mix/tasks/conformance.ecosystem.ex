# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Ecosystem do
  @moduledoc """
  Surveys every registered data layer and writes `ECOSYSTEM.md`, with a column
  per data layer, plus `surveys/features-<adapter>.md` for each one that ran.

      MIX_ENV=test mix conformance.ecosystem
      MIX_ENV=test mix conformance.ecosystem mysql csv

  Data layers whose storage is not available are reported as not run.
  """
  use Mix.Task
  @shortdoc "Survey every data layer and write ECOSYSTEM.md"
  def run(names) do
    Mix.Task.run("app.start")

    adapters =
      case names do
        [] -> Ash.Conformance.Adapter.every()
        names -> Enum.map(names, &Ash.Conformance.Adapter.find!/1)
      end

    results = Ash.Conformance.Report.Ecosystem.run(adapters)
    Ash.Conformance.Report.Ecosystem.write!(results)

    for result <- results do
      status =
        if result.unavailable,
          do: "not run: #{result.unavailable}",
          else: inspect(Enum.frequencies_by(result.rows, & &1.classification))

      Mix.shell().info("#{result.adapter.id()}: #{status}")
    end

    Mix.shell().info("Wrote ECOSYSTEM.md")
  end
end
