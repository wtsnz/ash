# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_invariants,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: ["lib"],
      deps: deps(),
      # Each dependency set has its own lock, deps and build.
      lockfile: if(main?(), do: "mix.main.lock", else: "mix.lock"),
      deps_path: if(main?(), do: "deps_main", else: "deps"),
      build_path: if(main?(), do: "_build_main", else: "_build")
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # Ash is always this checkout. The data layers are their latest Hex
  # releases, or each one's `main` branch with `INVARIANTS_DEPS=main`.
  defp deps do
    [
      {:ash, path: "..", override: true},
      data_layer(:ash_sql, "~> 0.8"),
      data_layer(:ash_postgres, "~> 2.15"),
      data_layer(:ash_sqlite, "~> 0.3"),
      {:simple_sat, "~> 0.1"}
    ]
  end

  defp data_layer(name, requirement) do
    if main?(),
      do:
        {name, git: "https://github.com/ash-project/#{name}.git", branch: "main", override: true},
      else: {name, requirement, override: true}
  end

  defp main? do
    case System.get_env("INVARIANTS_DEPS", "release") do
      "release" -> false
      "main" -> true
      other -> Mix.raise("INVARIANTS_DEPS must be release or main, got: #{other}")
    end
  end
end
