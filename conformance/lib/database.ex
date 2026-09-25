# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Database do
  @moduledoc false

  def setup!(repo) do
    config = repo.config()

    if repo == Ash.Conformance.PostgresRepo and
         not String.starts_with?(config[:database], "ash_conformance_") do
      raise ArgumentError, "CONFORMANCE_PG_DATABASE must start with ash_conformance_"
    end

    if database = config[:database], do: File.mkdir_p!(Path.dirname(database))

    case repo.__adapter__().storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, error} -> raise "Cannot create conformance database: #{inspect(error)}"
    end

    {:ok, _} = repo.start_link()
    Ecto.Migrator.up(repo, 1, Ash.Conformance.Schema, log: false)
    Ecto.Migrator.up(repo, 2, Ash.Conformance.IsolationSchema, log: false)
    Ecto.Migrator.up(repo, 4, Ash.Conformance.ValueSchema, log: false)
    Ecto.Migrator.up(repo, 5, Ash.Conformance.LedgerSchema, log: false)
    Ecto.Migrator.up(repo, 6, Ash.Conformance.RecordSchema, log: false)

    if repo == Ash.Conformance.PostgresRepo do
      Ecto.Migrator.up(repo, 3, Ash.Conformance.ContextSchema, log: false)
    end

    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end
end

defmodule Ash.Conformance.Schema do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:ac_parents, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:label, :text)
      add(:threshold, :bigint)
      add(:tenant_id, :text)
    end

    create table(:ac_children, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:parent_id, :bigint)
      add(:label, :text)
      add(:value, :bigint)
      add(:visible, :boolean)
      add(:tenant_id, :text)
    end

    create(index(:ac_children, [:parent_id]))

    create table(:ac_ratings, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:child_id, :bigint)
      add(:score, :bigint)
    end

    create table(:ac_tags, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:label, :text)
      add(:value, :bigint)
    end

    create table(:ac_links, primary_key: false) do
      add(:parent_id, :bigint, primary_key: true)
      add(:tag_id, :bigint, primary_key: true)
      add(:tenant_id, :text)
    end

    create table(:ac_child_tags, primary_key: false) do
      add(:child_id, :bigint, primary_key: true)
      add(:tag_id, :bigint, primary_key: true)
    end

    create table(:ac_events, primary_key: false) do
      add(:parent_id, :bigint)
      add(:value, :bigint)
    end
  end
end

defmodule Ash.Conformance.ValueSchema do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:ac_readings, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:parent_id, :bigint)
      add(:amount, :decimal)
      add(:taken_on, :date)
      add(:taken_at, :utc_datetime_usec)
      add(:taken_time, :time)
    end
  end
end

defmodule Ash.Conformance.RecordSchema do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_records, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:code, :text, null: false)
      add(:name, :text)
      add(:quantity, :bigint)
      add(:price, :decimal)
      add(:ratio, :float)
      add(:active, :boolean)
      add(:status, :text)
      add(:born_on, :date)
      add(:seen_at, :utc_datetime_usec)
      add(:opens_at, :time)
      add(:external_id, :uuid)
      add(:tags, {:array, :text})
      add(:metadata, :map)
      add(:address, :map)
    end

    create(unique_index(:dc_records, [:code], name: :dc_records_code_index))
  end
end

defmodule Ash.Conformance.LedgerSchema do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_ledger, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:amount, :bigint)
    end
  end
end

defmodule Ash.Conformance.IsolationSchema do
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
