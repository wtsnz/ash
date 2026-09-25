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
      # Each dependency set has its own lock, deps and build, so switching
      # between them never rebuilds or rewrites the other.
      lockfile: dependency_set_path("mix.lock", "mix.upstream.lock"),
      deps_path: dependency_set_path("deps", "deps_upstream"),
      build_path: dependency_set_path("_build", "_build_upstream"),
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
      adapter(:ash_sql, "CONFORMANCE_ASH_SQL_PATH", ash_sql_source()),
      {:simple_sat, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      adapter(:ash_sqlite, "CONFORMANCE_ASH_SQLITE_PATH", ash_sqlite_source()),
      adapter(:ash_postgres, "CONFORMANCE_ASH_POSTGRES_PATH", ash_postgres_source()),
      # Ecosystem data layers, surveyed without reviewed expectations.
      {:ash_csv, "~> 0.9.9"},
      {:ash_clickhouse, "~> 0.7.3"},
      adapter(:ash_mysql, "CONFORMANCE_ASH_MYSQL_PATH",
        git: "https://github.com/ash-project/ash_mysql.git",
        ref: "99684ca01850fb6c5e0606522411baf6387028aa"
      )
    ]
  end

  # `pinned` (the default) is the unreleased aggregate work under review.
  # `upstream` is ash-project main for every adapter, locked in
  # mix.upstream.lock; `mix deps.update` moves it forward deliberately.
  defp dependency_set do
    case System.get_env("CONFORMANCE_DEPS", "pinned") do
      set when set in ["pinned", "upstream"] -> set
      other -> Mix.raise("CONFORMANCE_DEPS must be pinned or upstream, got: #{other}")
    end
  end

  defp dependency_set_path(pinned, upstream),
    do: if(dependency_set() == "upstream", do: upstream, else: pinned)

  defp ash_sql_source do
    case dependency_set() do
      "pinned" ->
        [
          git: "https://github.com/wtsnz/ash_sql.git",
          ref: "0985b9fdcca0a0919defdf76b0c44115fa8b8340",
          override: true
        ]

      "upstream" ->
        [git: "https://github.com/ash-project/ash_sql.git", branch: "main", override: true]
    end
  end

  defp ash_sqlite_source do
    case dependency_set() do
      "pinned" ->
        [
          git: "https://github.com/wtsnz/ash_sqlite.git",
          ref: "46a4b869450a2a961ef9af44b5b69da2d5aff29c"
        ]

      "upstream" ->
        [git: "https://github.com/ash-project/ash_sqlite.git", branch: "main"]
    end
  end

  defp ash_postgres_source do
    case dependency_set() do
      "pinned" ->
        [
          git: "https://github.com/ash-project/ash_postgres.git",
          ref: "945073e431ec6eb3fbbb831a8ce5b561d8f8cd35"
        ]

      "upstream" ->
        [git: "https://github.com/ash-project/ash_postgres.git", branch: "main"]
    end
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
