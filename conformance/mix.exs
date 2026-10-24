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
      lockfile: lockfile(),
      deps_path: dependency_set_path("deps", "deps"),
      build_path: dependency_set_path("_build", "_build"),
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

  defp lockfile do
    case dependency_set() do
      "release" -> "mix.lock"
      set -> "mix.#{set}.lock"
    end
  end

  def application, do: [extra_applications: [:logger]]

  def cli, do: [preferred_envs: [check: :test]]

  defp deps do
    [
      core(:ash, "CONFORMANCE_ASH_PATH", "3.37.0"),
      core(:ash_sql, "CONFORMANCE_ASH_SQL_PATH", "0.8.3"),
      {:simple_sat, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      core(:ash_sqlite, "CONFORMANCE_ASH_SQLITE_PATH", "0.2.19"),
      core(:ash_postgres, "CONFORMANCE_ASH_POSTGRES_PATH", "2.15.1"),
      # Ecosystem data layers, surveyed without reviewed expectations.
      {:ash_csv, "~> 0.9.9"},
      {:ash_clickhouse, "~> 0.7.3"},
      adapter(:ash_mysql, "CONFORMANCE_ASH_MYSQL_PATH",
        git: "https://github.com/ash-project/ash_mysql.git",
        ref: "99684ca01850fb6c5e0606522411baf6387028aa"
      )
    ]
  end

  # `release` (the default) is the latest Hex release of Ash, AshSQL,
  # AshSqlite and AshPostgres. `main` is each one's `main` branch from GitHub,
  # locked in mix.main.lock. With `CONFORMANCE_MAIN_DIR`, a directory holding
  # `ash/`, `ash_sql/`, `ash_sqlite/` and `ash_postgres/` checkouts, `main`
  # uses those as path dependencies instead, with a lock, deps and build of
  # its own that git ignores. Each set has its own lock, deps and build.
  defp dependency_set do
    case System.get_env("CONFORMANCE_DEPS", "release") do
      "release" ->
        "release"

      "main" ->
        if System.get_env("CONFORMANCE_MAIN_DIR") in [nil, ""], do: "main", else: "main_local"

      other ->
        Mix.raise("CONFORMANCE_DEPS must be release or main, got: #{other}")
    end
  end

  defp dependency_set_path(release, suffix) do
    case dependency_set() do
      "release" -> release
      set -> "#{suffix}_#{set}"
    end
  end

  # The release from Hex, or `main`, unless a local checkout is named
  # explicitly. Every core package overrides, so the ecosystem data layers'
  # own requirements can't pull in another version.
  defp core(name, variable, version) do
    case {System.get_env(variable), dependency_set()} do
      {path, _} when path not in [nil, ""] ->
        {name, path: Path.expand(path), override: true}

      {_, "main_local"} ->
        {name,
         path: Path.join(System.get_env("CONFORMANCE_MAIN_DIR"), to_string(name)), override: true}

      {_, "main"} ->
        {name, git: "https://github.com/ash-project/#{name}.git", branch: "main", override: true}

      {_, "release"} ->
        {name, version, override: true}
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
