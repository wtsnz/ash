# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres.SchemaParent do
  @moduledoc false
  use Ash.Conformance.Resource, adapter: :postgres, table: "dc_schema_parents"

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
  use Ash.Conformance.Resource, adapter: :postgres, table: "dc_schema_items"

  attributes do
    attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:parent_id, :integer, public?: true)
    attribute(:value, :integer, public?: true)
  end

  multitenancy do
    strategy(:context)
  end
end

defmodule Ash.Conformance.ContextSchema do
  @moduledoc false
  use Ecto.Migration

  def change do
    for schema <- ["dc_tenant_a", "dc_tenant_b"] do
      execute("CREATE SCHEMA #{schema}", "DROP SCHEMA #{schema}")

      create table(:dc_schema_parents, primary_key: false, prefix: schema) do
        add(:id, :bigint, primary_key: true)
      end

      create table(:dc_schema_items, primary_key: false, prefix: schema) do
        add(:id, :bigint, primary_key: true)
        add(:parent_id, :bigint)
        add(:value, :bigint)
      end
    end
  end
end

defmodule Ash.Conformance.ContextFixtures do
  @moduledoc false
  def seed!(adapter) do
    for {tenant, rows} <- [
          {"dc_tenant_a", [%{id: 1, parent_id: 1, value: 2}, %{id: 2, parent_id: 1, value: 3}]},
          {"dc_tenant_b", [%{id: 1, parent_id: 1, value: 70}, %{id: 2, parent_id: 2, value: 90}]}
        ] do
      adapter.persist!(:schema_parent, [%{id: 1}, %{id: 2}], tenant: tenant)
      adapter.persist!(:schema_item, rows, tenant: tenant)
    end

    %{adapter: adapter}
  end
end
