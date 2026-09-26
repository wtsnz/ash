# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Sqlite do
  @moduledoc false
  use Ash.Conformance.Adapter, id: :sqlite, label: "AshSqlite", package: :ash_sqlite

  def expectations,
    do:
      Ash.Conformance.Contracts.Records.resolve(
        __MODULE__,
        Ash.Conformance.Sqlite.Expectations.rules()
      )

  def gaps, do: Ash.Conformance.Sqlite.Gaps.all()
  def fixture?(_fixture), do: true
  def instrumentation, do: Ash.Conformance.SQL.Instrumentation
  def repo, do: Ash.Conformance.SqliteRepo
  def custom_aggregate, do: Ash.Conformance.SqliteSum
  def manual_relationship, do: Ash.Conformance.Sqlite.Manual

  def resource_config(table) do
    {AshSqlite.DataLayer,
     quote do
       sqlite do
         table(unquote(table))
         repo(Ash.Conformance.SqliteRepo)
       end
     end}
  end

  def notes,
    do: [
      "The identity with `nils_distinct?: false` gets a plain unique index: AshSqlite's " <>
        "migration generator writes `nulls_distinct: false`, which ecto_sqlite3 rejects " <>
        "(\"`nulls_distinct` is not supported with SQLite3\")."
    ]

  def setup! do
    Ash.Conformance.SQL.Database.setup!(repo(),
      replace: %{13 => Ash.Conformance.SQL.Migrations.IdentitiesPlain},
      storage: {__MODULE__, &Ash.Conformance.SQL.Columns.ash_sql/1}
    )
  end

  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())

  def benchmark_persist!(role, rows) do
    Enum.each(Enum.chunk_every(rows, 500), &repo().insert_all(resource(role), &1))
  end

  def server_info do
    [[version]] = repo().query!("select sqlite_version()").rows

    %{
      version: version,
      settings:
        Map.new(~w(journal_mode synchronous cache_size), fn name ->
          {name, repo().query!("PRAGMA #{name}").rows}
        end),
      transport: "embedded",
      write_transactions?: repo().write_transactions?()
    }
  end
end

defmodule Ash.Conformance.SqliteRepo do
  @moduledoc false
  use AshSqlite.Repo, otp_app: :ash_conformance

  # AshSQLite recommends write transactions and its installer enables them.
  def write_transactions?, do: true
end

# AshSQLite gained custom aggregates in the unreleased aggregate work. Against
# a release without them, the module has no SQL implementation and the
# custom-aggregate scenarios fail at runtime instead.
if Code.ensure_loaded?(AshSqlite.CustomAggregate) do
  defmodule Ash.Conformance.SqliteSum do
    @moduledoc false
    use Ash.Resource.Aggregate.CustomAggregate
    use AshSqlite.CustomAggregate
    import Ecto.Query
    def dynamic(opts, binding), do: dynamic(sum(field(as(^binding), ^opts[:field])))
  end
else
  defmodule Ash.Conformance.SqliteSum do
    @moduledoc false
    use Ash.Resource.Aggregate.CustomAggregate
  end
end

defmodule Ash.Conformance.Sqlite.Manual do
  @moduledoc false
  use AshSqlite.ManualRelationship
  use Ash.Conformance.SQL.Manual, prefix: :ash_sqlite
end

defmodule Ash.Conformance.Sqlite.Resources do
  @moduledoc "Every shared resource role, instantiated for SQLite."
  use Ash.Conformance.Resources,
    namespace: Ash.Conformance.Sqlite,
    adapter: Ash.Conformance.Sqlite
end
