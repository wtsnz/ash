# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres do
  @moduledoc false
  use Ash.Conformance.Adapter, id: :postgres, label: "AshPostgres", package: :ash_postgres

  def expectations,
    do:
      Ash.Conformance.Contracts.Records.resolve(
        __MODULE__,
        Ash.Conformance.Postgres.Expectations.rules()
      )

  def gaps, do: Ash.Conformance.Postgres.Gaps.all()
  def fixture?(_fixture), do: true
  def profiles, do: [:shared, :context_tenancy]
  def instrumentation, do: Ash.Conformance.SQL.Instrumentation
  def repo, do: Ash.Conformance.PostgresRepo
  def custom_aggregate, do: Ash.Conformance.PostgresSum
  def manual_relationship, do: Ash.Conformance.Postgres.Manual

  def resource_config(table) do
    {AshPostgres.DataLayer,
     quote do
       postgres do
         table(unquote(table))
         repo(Ash.Conformance.PostgresRepo)
       end
     end}
  end

  def setup! do
    unless String.starts_with?(repo().config()[:database], "ash_conformance_") do
      raise ArgumentError, "CONFORMANCE_PG_DATABASE must start with ash_conformance_"
    end

    Ash.Conformance.SQL.Database.setup!(repo(),
      migrations: [
        {3, Ash.Conformance.SQL.Migrations.ContextTenancy},
        {7, Ash.Conformance.Postgres.Citext},
        {9, Ash.Conformance.Postgres.AshFunctions}
      ],
      storage: {__MODULE__, &Ash.Conformance.SQL.Columns.ash_sql/1}
    )
  end

  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())

  def benchmark_persist!(role, rows) do
    Enum.each(Enum.chunk_every(rows, 500), &repo().insert_all(resource(role), &1))
  end

  def server_info do
    [[version]] = repo().query!("show server_version").rows

    %{
      version: version,
      settings:
        Map.new(~w(shared_buffers work_mem max_connections), fn name ->
          {name, repo().query!("SHOW #{name}").rows}
        end),
      transport: "TCP",
      write_transactions?: :always
    }
  end
end

# AshPostgres documents this for `:duration` attributes: intervals must decode
# as `Duration`, which only a Postgrex types module can set.
Postgrex.Types.define(
  Ash.Conformance.PostgrexTypes,
  Ecto.Adapters.Postgres.extensions(),
  interval_decode_type: Duration
)

# AshPostgres stores case-insensitive strings as citext, which an application
# using them installs.
defmodule Ash.Conformance.Postgres.Citext do
  @moduledoc false
  use Ecto.Migration
  def change, do: execute("CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION citext")
end

# The SQL functions AshPostgres's migration generator installs for the
# "ash-functions" extension: `||` and `&&` semantics and error expressions.
defmodule Ash.Conformance.Postgres.AshFunctions do
  @moduledoc false
  use Ecto.Migration

  def up do
    Code.eval_string(AshPostgres.MigrationGenerator.AshFunctions.install(nil), [], __ENV__)
  end

  def down, do: :ok
end

defmodule Ash.Conformance.PostgresRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_conformance, warn_on_missing_ash_functions?: false
  # What AshPostgres's installer configures for a new application.
  def installed_extensions, do: ["ash-functions", "citext"]
  def min_pg_version, do: %Version{major: 17, minor: 0, patch: 0}
end

defmodule Ash.Conformance.PostgresSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
  use AshPostgres.CustomAggregate
  import Ecto.Query
  def dynamic(opts, binding), do: dynamic(fragment("sum(?)", field(as(^binding), ^opts[:field])))
end

defmodule Ash.Conformance.Postgres.Manual do
  @moduledoc false
  use AshPostgres.ManualRelationship
  use Ash.Conformance.SQL.Manual, prefix: :ash_postgres
end

defmodule Ash.Conformance.Postgres.Resources do
  @moduledoc "Every shared resource role, instantiated for PostgreSQL."
  use Ash.Conformance.Resources,
    namespace: Ash.Conformance.Postgres,
    adapter: Ash.Conformance.Postgres
end

defmodule Ash.Conformance.Postgres.SchemaParent do
  @moduledoc false
  use Ash.Conformance.Resources.Base,
    adapter: Ash.Conformance.Postgres,
    table: "dc_schema_parents"

  attributes do
    attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
  end

  multitenancy do
    strategy(:context)
  end

  actions do
    read :paged do
      pagination(offset?: true, countable: true, required?: false)
    end
  end

  relationships do
    has_many(:items, Ash.Conformance.Postgres.SchemaItem,
      destination_attribute: :parent_id,
      sort: [id: :asc],
      public?: true
    )
  end

  aggregates do
    count(:item_count, :items, public?: true)
    sum(:item_sum, :items, :value, default: 0, public?: true)
  end
end

defmodule Ash.Conformance.Postgres.SchemaItem do
  @moduledoc false
  use Ash.Conformance.Resources.Base, adapter: Ash.Conformance.Postgres, table: "dc_schema_items"

  attributes do
    attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:parent_id, :integer, public?: true)
    attribute(:value, :integer, public?: true)
  end

  multitenancy do
    strategy(:context)
  end
end
