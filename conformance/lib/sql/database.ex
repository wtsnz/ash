# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Database do
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
    Ecto.Migrator.up(repo, 1, Ash.Conformance.SQL.Migrations.Aggregate, log: false)
    Ecto.Migrator.up(repo, 2, Ash.Conformance.SQL.Migrations.Isolation, log: false)
    Ecto.Migrator.up(repo, 4, Ash.Conformance.SQL.Migrations.Values, log: false)
    Ecto.Migrator.up(repo, 5, Ash.Conformance.SQL.Migrations.Ledger, log: false)
    Ecto.Migrator.up(repo, 6, Ash.Conformance.SQL.Migrations.Records, log: false)

    if repo == Ash.Conformance.PostgresRepo do
      Ecto.Migrator.up(repo, 3, Ash.Conformance.SQL.Migrations.ContextTenancy, log: false)
    end

    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end
end
