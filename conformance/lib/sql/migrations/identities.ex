# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Identities do
  @moduledoc """
  The identity tables, with the unique indexes AshPostgres's migration
  generator writes: `nulls_distinct: false` for the identity that sets
  `nils_distinct?: false`.
  """
  use Ecto.Migration

  def change do
    for table <- [:idn_rows, :idx_rows] do
      create table(table, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:code, :string, null: false)
        add(:scope, :string)
        add(:value, :bigint)
        add(:note, :string)
      end
    end

    create(unique_index(:idn_rows, [:code, :scope]))
    create(unique_index(:idx_rows, [:code, :scope], nulls_distinct: false))
  end
end

defmodule Ash.Conformance.SQL.Migrations.IdentitiesPlain do
  @moduledoc """
  The identity tables with plain unique indexes, for databases whose Ecto
  adapter rejects `nulls_distinct` (SQLite, MySQL). Nil values then never
  conflict, whatever the identity says.
  """
  use Ecto.Migration

  def change do
    for table <- [:idn_rows, :idx_rows] do
      create table(table, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:code, :string, null: false)
        add(:scope, :string)
        add(:value, :bigint)
        add(:note, :string)
      end
    end

    create(unique_index(:idn_rows, [:code, :scope]))
    create(unique_index(:idx_rows, [:code, :scope]))
  end
end
