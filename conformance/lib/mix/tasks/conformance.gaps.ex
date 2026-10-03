# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Gaps do
  @moduledoc false
  use Mix.Task
  @shortdoc "Render GAPS.md from the shared, AshSQL and per-adapter gaps"

  def run(_args) do
    Mix.Task.run("compile")
    File.write!("GAPS.md", Ash.Conformance.Contracts.Gaps.markdown())
    Mix.shell().info("Wrote GAPS.md")
  end
end
