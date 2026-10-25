# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.Tables do
  @moduledoc """
  The SQL layers' tables, created once per run, and the sandbox that gives
  each observation an empty database: everything it writes is rolled back.
  """

  defmodule Migration do
    @moduledoc false
    use Ecto.Migration

    def change do
      create table(:customers, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:name, :text)
      end

      create table(:events, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:name, :text)
        add(:recorded, :bigint)
      end

      create table(:orders, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:org_id, :bigint)
        add(:event_id, :bigint)
        add(:customer_id, :bigint)
        add(:visible, :boolean)
      end

      create(unique_index(:orders, [:org_id, :event_id, :customer_id]))

      create table(:notes, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:org_id, :bigint, null: false)
        add(:local_id, :bigint, null: false)
        add(:body, :text)
        add(:value, :bigint)
        add(:list_id, :bigint)
        add(:visible, :boolean)
      end

      create(unique_index(:notes, [:org_id, :local_id]))

      create table(:lists, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:org_id, :bigint, null: false)
        add(:name, :text)
      end

      create table(:people, primary_key: false) do
        add(:id, :bigint, primary_key: true)
        add(:name, :text)
        add(:secret, :text)
        add(:event_id, :bigint)
        add(:profile, :map)
        add(:cards, {:array, :map})
        add(:payment, :map)
      end
    end
  end

  defmodule SchemaMigration do
    @moduledoc false
    use Ecto.Migration

    def change do
      for schema <- Ash.Invariants.World.schemas() do
        execute("CREATE SCHEMA IF NOT EXISTS #{schema}", "DROP SCHEMA #{schema}")

        create table(:orders, primary_key: false, prefix: schema) do
          add(:id, :bigint, primary_key: true)
          add(:event_id, :bigint)
          add(:customer_id, :bigint)
          add(:visible, :boolean)
        end

        create(unique_index(:orders, [:event_id, :customer_id], prefix: schema))
      end
    end
  end

  defmodule AshFunctions do
    @moduledoc false
    use Ecto.Migration

    def up,
      do: Code.eval_string(AshPostgres.MigrationGenerator.AshFunctions.install(nil), [], __ENV__)

    def down, do: :ok
  end

  @doc "Creates the database from scratch, with `schemas` for schema-based tenancy."
  def setup!(repo, schemas) do
    config = repo.config()
    adapter = repo.__adapter__()
    if database = config[:database], do: File.mkdir_p!(Path.dirname(database))

    case adapter.storage_down(config) do
      :ok -> :ok
      {:error, :already_down} -> :ok
      {:error, error} -> raise "Cannot drop the invariants database: #{inspect(error)}"
    end

    :ok = adapter.storage_up(config)
    {:ok, _} = repo.start_link()

    migrations =
      [{1, Migration}] ++
        if(schemas == [], do: [], else: [{2, SchemaMigration}, {3, AshFunctions}])

    for {version, migration} <- migrations,
        do: Ecto.Migrator.up(repo, version, migration, log: false)

    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end

  @doc "Runs `fun` in its own process and sandbox transaction, rolled back afterwards."
  def isolated(repo, fun) do
    fn ->
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo)

      try do
        fun.()
      after
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
      end
    end
    |> Task.async()
    |> Task.await(:infinity)
  end
end
