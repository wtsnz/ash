# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.ContextTenancy do
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
