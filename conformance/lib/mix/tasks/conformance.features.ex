# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Features do
  @moduledoc false
  use Mix.Task
  @shortdoc "Generate the per-data-layer feature report from declared contracts"
  def run([]) do
    Mix.Task.run("compile")
    File.write!("FEATURES.md", Ash.Conformance.FeatureReport.declared())
    Mix.shell().info("Wrote FEATURES.md")
  end
end
