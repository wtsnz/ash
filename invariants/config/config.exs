# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT
import Config

config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false
config :ash, :default_string_length_count, :codepoints
config :logger, level: :warning

config :ash_invariants, ecto_repos: []

config :ash_invariants, Ash.Invariants.SqliteRepo,
  database: Path.expand("../tmp/invariants.sqlite3", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 4,
  busy_timeout: 5_000

config :ash_invariants, Ash.Invariants.PostgresRepo,
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  database: System.get_env("INVARIANTS_PG_DATABASE", "ash_invariants"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 4
