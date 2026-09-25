# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
import Config

config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false
config :ash, :default_string_length_count, :codepoints
config :logger, level: :warning

# The data layers the suite runs. Reviewed adapters have expectation records
# and gate CI; unreviewed ones run only as surveys in the ecosystem report.
config :ash_conformance,
  adapters: [Ash.Conformance.Sqlite, Ash.Conformance.Postgres],
  unreviewed_adapters: [Ash.Conformance.Ets, Ash.Conformance.Csv, Ash.Conformance.Mysql]

config :ash_conformance, Ash.Conformance.SqliteRepo,
  database: Path.expand("../tmp/data_layer.sqlite3", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2,
  migration_lock: false,
  # Connections opening while the first creates the file wait instead of
  # failing with "database is locked".
  busy_timeout: 5_000

config :ash_conformance, Ash.Conformance.PostgresRepo,
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  database: System.get_env("CONFORMANCE_PG_DATABASE", "ash_conformance_local"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

config :ash_conformance, Ash.Conformance.MysqlRepo,
  hostname: System.get_env("MYSQL_HOST", "localhost"),
  port: String.to_integer(System.get_env("MYSQL_PORT", "3306")),
  username: System.get_env("MYSQL_USER", "root"),
  password: System.get_env("MYSQL_PASSWORD", "mysql"),
  database: "ash_conformance_local",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2
