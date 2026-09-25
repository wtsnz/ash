# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Database do
  @moduledoc false

  @doc """
  Creates the database, runs the shared migrations and any `migrations:` the
  adapter adds as `{version, module}`, and puts the sandbox in manual mode.
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

    migrations =
      [
        {1, Ash.Conformance.SQL.Migrations.Aggregate},
        {2, Ash.Conformance.SQL.Migrations.Isolation},
        {4, Ash.Conformance.SQL.Migrations.Values},
        {5, Ash.Conformance.SQL.Migrations.Ledger},
        {6, Ash.Conformance.SQL.Migrations.Records}
      ] ++ Keyword.get(opts, :migrations, [])

    for {version, migration} <- migrations do
      Ecto.Migrator.up(repo, version, migration, log: false)
    end

    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end
end
