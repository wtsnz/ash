# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Isolation do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_parents, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:tenant_id, :bigint, null: false)
      add(:local_id, :bigint, null: false)
      add(:owner_id, :bigint, null: false)
      add(:name, :text)
    end

    create(unique_index(:dc_parents, [:tenant_id, :local_id], name: :dc_parents_local_id_index))

    create table(:dc_items, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:tenant_id, :bigint, null: false)
      add(:local_id, :bigint, null: false)
      add(:parent_key, :bigint, null: false)
      add(:owner_id, :bigint, null: false)
      add(:department, :bigint, null: false)
      add(:value, :bigint)
    end

    create(unique_index(:dc_items, [:tenant_id, :local_id], name: :dc_items_local_id_index))
    create(index(:dc_items, [:tenant_id, :parent_key]))
  end
end
