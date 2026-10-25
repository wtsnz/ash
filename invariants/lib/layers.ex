# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.Layer do
  @moduledoc """
  A data layer under test: how its resources store their rows, which shapes
  it runs, and how one observation gets a database of its own.
  """

  @doc "The layer's short name, as test names and known failures use it."
  @callback id() :: atom()

  @doc "The shapes it runs; see `Ash.Invariants.Resources`."
  @callback shapes() :: [atom()]

  @doc "Whether it supports `has_many through:` relationships."
  @callback through?() :: boolean()

  @doc "The data layer module and its DSL block for a table."
  @callback data_layer(table :: String.t()) :: {module(), Macro.t()}

  @doc "Creates the database and tables, once per test run."
  @callback setup!() :: :ok

  @doc "Runs `fun` with a fresh, empty database that only this process sees."
  @callback isolated((-> term())) :: term()

  @doc "Every layer, in the order tests run them."
  def all, do: [Ash.Invariants.Ets, Ash.Invariants.Sqlite, Ash.Invariants.Postgres]

  @doc "The resource module for a role under a layer: `resource(Ets, Note)`."
  def resource(layer, role), do: Module.concat(layer, role)
end

defmodule Ash.Invariants.Ets do
  @moduledoc "`Ash.DataLayer.Ets`, with private tables: each process sees only its own rows."
  @behaviour Ash.Invariants.Layer

  @impl true
  def id, do: :ets
  @impl true
  def shapes, do: [:tenant, :secure, :schema]
  @impl true
  def through?, do: true

  @impl true
  def data_layer(table) do
    {Ash.DataLayer.Ets,
     quote do
       ets do
         private?(true)
         table(unquote(String.to_atom(table)))
       end
     end}
  end

  @impl true
  def setup!, do: :ok

  @impl true
  def isolated(fun), do: fun |> Task.async() |> Task.await(:infinity)
end

defmodule Ash.Invariants.Sqlite do
  @moduledoc "AshSqlite. It has no schema-based tenancy and no `through` relationships."
  @behaviour Ash.Invariants.Layer

  @impl true
  def id, do: :sqlite
  @impl true
  def shapes, do: [:tenant, :secure]
  @impl true
  def through?, do: false

  @impl true
  def data_layer(table) do
    {AshSqlite.DataLayer,
     quote do
       sqlite do
         table(unquote(table))
         repo(Ash.Invariants.SqliteRepo)
       end
     end}
  end

  @impl true
  def setup!, do: Ash.Invariants.Tables.setup!(Ash.Invariants.SqliteRepo, [])

  @impl true
  def isolated(fun), do: Ash.Invariants.Tables.isolated(Ash.Invariants.SqliteRepo, fun)
end

defmodule Ash.Invariants.Postgres do
  @moduledoc "AshPostgres, with schema-based tenancy in the `org_1` and `org_2` schemas."
  @behaviour Ash.Invariants.Layer

  @impl true
  def id, do: :postgres
  @impl true
  def shapes, do: [:tenant, :secure, :schema]
  @impl true
  def through?, do: true

  @impl true
  def data_layer(table) do
    {AshPostgres.DataLayer,
     quote do
       postgres do
         table(unquote(table))
         repo(Ash.Invariants.PostgresRepo)
       end
     end}
  end

  @impl true
  def setup! do
    Ash.Invariants.Tables.setup!(Ash.Invariants.PostgresRepo, Ash.Invariants.World.schemas())
  end

  @impl true
  def isolated(fun), do: Ash.Invariants.Tables.isolated(Ash.Invariants.PostgresRepo, fun)
end

defmodule Ash.Invariants.SqliteRepo do
  @moduledoc false
  use AshSqlite.Repo, otp_app: :ash_invariants
  def min_sqlite_version, do: %Version{major: 3, minor: 45, patch: 0}
end

defmodule Ash.Invariants.PostgresRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_invariants, warn_on_missing_ash_functions?: false
  def installed_extensions, do: ["ash-functions"]
  def min_pg_version, do: %Version{major: 16, minor: 0, patch: 0}
end
