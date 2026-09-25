# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Sqlite do
  @moduledoc false
  @behaviour Ash.Conformance.Adapter
  def id, do: :sqlite
  def expectations, do: Ash.Conformance.Contracts.Expectations.builtin(:sqlite)
  def fixture?(_fixture), do: true
  def profiles, do: [:shared]
  def instrumentation, do: Ash.Conformance.SQL.Instrumentation
  def repo, do: Ash.Conformance.SqliteRepo

  def resource(role),
    do: Module.concat(Ash.Conformance.Sqlite, Macro.camelize(to_string(role)))

  def custom_aggregate, do: Ash.Conformance.SqliteSum
  def setup!, do: Ash.Conformance.SQL.Database.setup!(repo())
  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())

  def benchmark_persist!(role, rows) do
    Enum.each(Enum.chunk_every(rows, 500), &repo().insert_all(resource(role), &1))
  end

  def persist!(role, rows, opts) do
    Ash.Seed.seed!(resource(role), rows, opts)
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
  use Ash.Conformance.Resources.Manual, prefix: :ash_sqlite
end

defmodule Ash.Conformance.Sqlite.Resources do
  @moduledoc "Every shared resource role, instantiated for SQLite."
  use Ash.Conformance.Resources.Aggregate, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
  use Ash.Conformance.Resources.Records, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
  use Ash.Conformance.Resources.Isolation, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
  use Ash.Conformance.Resources.Writes, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
end
