# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Fuzz do
  @shortdoc "Checks generated filters against Ash's evaluation"
  @moduledoc """
  Generates filters, runs them on an adapter, and reports each distinct
  disagreement with an oracle, shrunk to a minimal filter. See
  `Ash.Conformance.Fuzz`.

      MIX_ENV=test mix conformance.fuzz sqlite --runs 500 --rounds 5 --seed 7
      MIX_ENV=test mix conformance.fuzz sqlite --oracle runtime
      MIX_ENV=test mix conformance.fuzz ash

  `--oracle sql` (the default) checks against SQL's three-valued logic, as
  the expressions guide specifies; `--oracle runtime` against Ash's own
  in-memory evaluation. The name `ash` checks Ash's evaluation itself
  against SQL's logic, with no data layer.

  The report goes to `results/fuzz-<adapter>.md`. Nothing is written into
  expectations: each disagreement is a lead to triage.
  """
  use Mix.Task

  @switches [runs: :integer, rounds: :integer, seed: :integer, output: :string, oracle: :string]

  @impl Mix.Task
  def run(args) do
    {opts, [name], _} = OptionParser.parse(args, strict: @switches)
    Mix.Task.run("app.start")
    opts = Keyword.update(opts, :oracle, :sql, &String.to_existing_atom/1)

    {label, failures} =
      case name do
        "ash" ->
          adapter = Ash.Conformance.Adapter.find!("ets")
          adapter.setup!()
          {"Ash's evaluation", Ash.Conformance.Fuzz.runtime([adapter: adapter] ++ opts)}

        name ->
          adapter = Ash.Conformance.Adapter.find!(name)
          {adapter.label(), Ash.Conformance.Fuzz.run(adapter, opts)}
      end

    output = Keyword.get(opts, :output, Ash.Conformance.Report.results_dir())
    File.mkdir_p!(output)
    path = Path.join(output, "fuzz-#{name}.md")
    File.write!(path, Ash.Conformance.Fuzz.markdown(label, failures, opts))

    Mix.shell().info("#{length(failures)} disagreements. Report: #{path}")
  end
end
