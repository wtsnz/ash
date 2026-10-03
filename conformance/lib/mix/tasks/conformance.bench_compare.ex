# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.BenchCompare do
  @moduledoc false
  use Mix.Task
  @shortdoc "Compare compatible benchmark JSON reports"
  def run([base_path, current_path]) do
    Mix.Task.run("app.start")
    read = fn path -> path |> File.read!() |> Jason.decode!() end
    changes = Ash.Conformance.Benchmark.compare!(read.(base_path), read.(current_path))
    Mix.shell().info("Compatible median changes; informational, no regression threshold.")
    Mix.shell().info(Jason.encode!(changes, pretty: true))
  end

  def run(_), do: Mix.raise("Usage: mix conformance.bench_compare BASE.json CURRENT.json")
end
