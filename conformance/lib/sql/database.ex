# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Database do
  @moduledoc false

  @doc """
  Creates the database, runs the shared migrations and any `migrations:` the
  adapter adds as `{version, module}`, and puts the sandbox in manual mode.
  `replace:` swaps a shared migration by version, for a database that cannot
  create one of its column types. `storage: {adapter, column}` also creates
  the tier-1 tables, one at a time, with `column` choosing each value column.
  """
  def setup!(repo, opts \\ []) do
    config = repo.config()

    if database = config[:database], do: File.mkdir_p!(Path.dirname(database))

    case repo.__adapter__().storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, error} -> raise "Cannot create conformance database: #{inspect(error)}"
    end

    {:ok, _} = repo.start_link()

    replace = Keyword.get(opts, :replace, %{})

    shared = [
      {1, Ash.Conformance.SQL.Migrations.Aggregate},
      {2, Ash.Conformance.SQL.Migrations.Isolation},
      {4, Ash.Conformance.SQL.Migrations.Values},
      {5, Ash.Conformance.SQL.Migrations.Ledger},
      {6, Ash.Conformance.SQL.Migrations.Records},
      {8, Ash.Conformance.SQL.Migrations.Policy},
      {10, Ash.Conformance.SQL.Migrations.Combination}
    ]

    migrations =
      Enum.map(shared, fn {version, migration} ->
        {version, Map.get(replace, version, migration)}
      end) ++ Keyword.get(opts, :migrations, [])

    for {version, migration} <- migrations do
      Ecto.Migrator.up(repo, version, migration, log: false)
    end

    with {adapter, column} <- Keyword.get(opts, :storage), do: provision!(adapter, repo, column)

    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end

  # Tier-1 tables are recreated on every setup, so a changed column type
  # always applies, and each one is created on its own.
  defp provision!(adapter, repo, column) do
    ecto = repo.__adapter__()
    meta = Ecto.Adapter.lookup_meta(repo)

    Ash.Conformance.Storage.provision(adapter, fn type ->
      role = Ash.Conformance.Storage.role(type.name)
      attribute = Ash.Resource.Info.attribute(adapter.resource(role), :value)

      {column_type, column_opts} =
        case column.(attribute) do
          {column_type, opts} when is_list(opts) -> {column_type, opts}
          column_type -> {column_type, []}
        end

      table = %Ecto.Migration.Table{
        name: Ash.Conformance.Storage.table(type.name),
        primary_key: false
      }

      column = describe(column_type, column_opts)

      try do
        {:ok, _} = ecto.execute_ddl(meta, {:drop_if_exists, table, :restrict}, [])

        {:ok, _} =
          ecto.execute_ddl(
            meta,
            {:create, table,
             [
               {:add, :id, :bigint, [primary_key: true]},
               {:add, :value, column_type, column_opts}
             ]},
            []
          )

        {:ok, column}
      rescue
        exception -> {:error, Ash.Conformance.Fixtures.reason(exception), column}
      end
    end)
  end

  defp describe(column_type, []), do: inspect(column_type)
  defp describe(column_type, opts), do: "#{inspect(column_type)} #{inspect(opts)}"
end
