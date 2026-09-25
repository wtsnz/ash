# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Probe do
  @moduledoc false
  use Mix.Task
  @shortdoc "Observe a scenario without accepting or requiring adapter expectations"

  def run([id]) do
    Mix.Task.run("app.start")

    scenario =
      Enum.find(Ash.Conformance.Catalog.all(), &(&1.id == id)) ||
        Mix.raise("Unknown scenario #{inspect(id)}")

    adapters = Ash.Conformance.Adapter.selected()

    for adapter <- adapters do
      unless scenario.profile in adapter.profiles(),
        do: Mix.raise("#{adapter.id()} does not provide profile #{scenario.profile}")
    end

    observations =
      for adapter <- adapters do
        adapter.setup!()
        Ash.Conformance.Probe.run(scenario, adapter)
      end

    report = %{schema_version: 1, mode: :probe, semantic_passes: 0, observations: observations}
    File.mkdir_p!("results/probes")
    # IDs come from the registry, not an arbitrary user-supplied output path.
    filename = String.replace(id, ~r/[^a-zA-Z0-9_.-]/, "_")
    path = "results/probes/#{filename}.json"
    File.write!(path, Jason.encode!(report, pretty: true) <> "\n")

    Mix.shell().info(
      "UNREVIEWED OBSERVATIONS, zero semantic passes. No expectations changed.\n#{Jason.encode!(report, pretty: true)}\n#{path}"
    )
  end

  def run(_), do: Mix.raise("Usage: mix conformance.probe SCENARIO_ID")
end
