# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Inventory do
  @moduledoc false
  use Mix.Task
  @shortdoc "Generate versioned coverage and resource-specific capability inventory"
  def run([]) do
    Mix.Task.run("app.start")
    File.mkdir_p!("results")
    File.write!("CAPABILITIES.md", Ash.Conformance.Contracts.Capabilities.markdown())
    File.write!("COVERAGE.md", Ash.Conformance.Report.Inventory.markdown())

    File.write!(
      "results/inventory.json",
      Jason.encode!(Ash.Conformance.Report.Inventory.document(), pretty: true) <> "\n"
    )

    Mix.shell().info("Wrote CAPABILITIES.md, COVERAGE.md and results/inventory.json")
  end
end
