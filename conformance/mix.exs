# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_conformance,
      version: "0.1.0",
      elixir: "~> 1.20.0",
      elixirc_paths: ["lib"],
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      aliases: [
        check: [
          "compile --warnings-as-errors",
          "format --check-formatted",
          "credo --strict",
          "test"
        ]
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  def cli, do: [preferred_envs: [check: :test]]

  defp deps do
    [
      {:ash, path: "..", override: true},
      adapter(:ash_sql, "CONFORMANCE_ASH_SQL_PATH",
        git: "https://github.com/wtsnz/ash_sql.git",
        ref: "0985b9fdcca0a0919defdf76b0c44115fa8b8340",
        override: true
      ),
      {:simple_sat, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      adapter(:ash_sqlite, "CONFORMANCE_ASH_SQLITE_PATH",
        git: "https://github.com/wtsnz/ash_sqlite.git",
        ref: "46a4b869450a2a961ef9af44b5b69da2d5aff29c"
      ),
      adapter(:ash_postgres, "CONFORMANCE_ASH_POSTGRES_PATH",
        git: "https://github.com/ash-project/ash_postgres.git",
        ref: "945073e431ec6eb3fbbb831a8ce5b561d8f8cd35"
      )
    ]
  end

  # The pinned revision unless a local checkout is named explicitly. Local paths
  # are for development only: they bypass mix.lock and are recorded in reports.
  defp adapter(name, variable, pinned) do
    case System.get_env(variable) do
      path when path in [nil, ""] -> {name, pinned}
      path -> {name, path: Path.expand(path), override: true}
    end
  end
end
