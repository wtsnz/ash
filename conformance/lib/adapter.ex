# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Adapter do
  @moduledoc """
  Database and resource configuration for the shared aggregate scenarios.

  Scenarios receive an adapter and ask it for a resource by role. They never
  branch on the adapter ID. Other data layers can implement this contract and
  provide the same fixture domain without depending on Ecto in the runner.
  """

  @callback id() :: atom()
  @callback resource(atom()) :: module()
  @callback custom_aggregate() :: module()
  @callback setup!() :: term()
  @callback checkout!() :: term()
  @callback checkin!() :: term()
  @callback profiles() :: [atom()]
  @callback persist!(atom(), [map()], keyword()) :: term()
  @callback instrumentation() :: module() | nil
  @callback benchmark_persist!(atom(), [map()]) :: term()

  def all, do: [Ash.Conformance.Sqlite, Ash.Conformance.Postgres]

  def selected do
    requested = System.get_env("CONFORMANCE_ADAPTERS", "sqlite,postgres") |> String.split(",")
    known = Map.new(all(), &{to_string(&1.id()), &1})

    Enum.map(requested, fn name ->
      Map.get(known, String.trim(name)) ||
        raise ArgumentError, "Unknown adapter: #{inspect(name)}"
    end)
    |> Enum.uniq()
  end
end

defmodule Ash.Conformance.SqliteRepo do
  @moduledoc false
  use AshSqlite.Repo, otp_app: :ash_conformance

  # AshSQLite recommends write transactions and its installer enables them.
  def write_transactions?, do: true
end

defmodule Ash.Conformance.PostgresRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_conformance, warn_on_missing_ash_functions?: false
  def installed_extensions, do: []
  def min_pg_version, do: %Version{major: 17, minor: 0, patch: 0}
end

defmodule Ash.Conformance.Sqlite do
  @moduledoc false
  @behaviour Ash.Conformance.Adapter
  def id, do: :sqlite
  def profiles, do: [:shared]
  def instrumentation, do: Ash.Conformance.SQLInstrumentation
  def repo, do: Ash.Conformance.SqliteRepo

  def resource(role),
    do: Module.concat(Ash.Conformance.Sqlite, Macro.camelize(to_string(role)))

  def custom_aggregate, do: Ash.Conformance.SqliteSum
  def setup!, do: Ash.Conformance.Database.setup!(repo())
  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())

  def benchmark_persist!(role, rows) do
    Enum.each(Enum.chunk_every(rows, 500), &repo().insert_all(resource(role), &1))
  end

  def persist!(role, rows, opts) do
    Ash.Seed.seed!(resource(role), rows, opts)
  end
end

defmodule Ash.Conformance.Postgres do
  @moduledoc false
  @behaviour Ash.Conformance.Adapter
  def id, do: :postgres
  def profiles, do: [:shared, :context_tenancy]
  def instrumentation, do: Ash.Conformance.SQLInstrumentation
  def repo, do: Ash.Conformance.PostgresRepo

  def resource(role),
    do: Module.concat(Ash.Conformance.Postgres, Macro.camelize(to_string(role)))

  def custom_aggregate, do: Ash.Conformance.PostgresSum
  def setup!, do: Ash.Conformance.Database.setup!(repo())
  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())

  def benchmark_persist!(role, rows) do
    Enum.each(Enum.chunk_every(rows, 500), &repo().insert_all(resource(role), &1))
  end

  def persist!(role, rows, opts) do
    Ash.Seed.seed!(resource(role), rows, opts)
  end
end

defmodule Ash.Conformance.SqliteSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
  use AshSqlite.CustomAggregate
  import Ecto.Query
  def dynamic(opts, binding), do: dynamic(sum(field(as(^binding), ^opts[:field])))
end

defmodule Ash.Conformance.PostgresSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
  use AshPostgres.CustomAggregate
  import Ecto.Query
  def dynamic(opts, binding), do: dynamic(fragment("sum(?)", field(as(^binding), ^opts[:field])))
end
