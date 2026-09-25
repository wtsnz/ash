# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres do
  @moduledoc false
  @behaviour Ash.Conformance.Adapter
  def id, do: :postgres
  def expectations, do: Ash.Conformance.Contracts.Expectations.builtin(:postgres)
  def fixture?(_fixture), do: true
  def profiles, do: [:shared, :context_tenancy]
  def instrumentation, do: Ash.Conformance.SQL.Instrumentation
  def repo, do: Ash.Conformance.PostgresRepo

  def resource(role),
    do: Module.concat(Ash.Conformance.Postgres, Macro.camelize(to_string(role)))

  def custom_aggregate, do: Ash.Conformance.PostgresSum
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

defmodule Ash.Conformance.PostgresRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_conformance, warn_on_missing_ash_functions?: false
  def installed_extensions, do: []
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
  use Ash.Conformance.Resources.Manual, prefix: :ash_postgres
end

defmodule Ash.Conformance.Postgres.Resources do
  @moduledoc "Every shared resource role, instantiated for PostgreSQL."
  use Ash.Conformance.Resources.Aggregate, namespace: Ash.Conformance.Postgres, adapter: :postgres
  use Ash.Conformance.Resources.Records, namespace: Ash.Conformance.Postgres, adapter: :postgres
  use Ash.Conformance.Resources.Isolation, namespace: Ash.Conformance.Postgres, adapter: :postgres
  use Ash.Conformance.Resources.Writes, namespace: Ash.Conformance.Postgres, adapter: :postgres
end

defmodule Ash.Conformance.Postgres.SchemaParent do
  @moduledoc false
  use Ash.Conformance.Resources.Base, adapter: :postgres, table: "dc_schema_parents"

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
  use Ash.Conformance.Resources.Base, adapter: :postgres, table: "dc_schema_items"

  attributes do
    attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:parent_id, :integer, public?: true)
    attribute(:value, :integer, public?: true)
  end

  multitenancy do
    strategy(:context)
  end
end
