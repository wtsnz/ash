# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Clickhouse do
  @moduledoc """
  AshClickhouse over ClickHouse's HTTP interface.

  Each shared table is created from the role that has every column, using
  AshClickhouse's column types and its default `MergeTree` engine ordered by
  the primary key.
  ClickHouse has no transactions to roll back, so each case starts from
  truncated tables instead. See `notes/0` for what differs from AshClickhouse's
  own setup.
  """
  use Ash.Conformance.Adapter, id: :clickhouse, label: "AshClickhouse", package: :ash_clickhouse

  alias Ash.Conformance.Adapter

  def repo, do: Ash.Conformance.ClickhouseRepo

  def resource_config(table) do
    {AshClickhouse.DataLayer,
     quote do
       import AshClickhouse.DataLayer.Dsl.Macros

       clickhouse do
         table(unquote(table))
         repo(Ash.Conformance.ClickhouseRepo)
       end
     end}
  end

  # ClickHouse does not enforce uniqueness.
  def identity_options, do: [pre_check?: true]

  def notes,
    do: [
      "Shared tables are created from AshClickhouse's column types rather than its generator, which " <>
        "rejects the records table: ClickHouse cannot wrap an array or map in `Nullable`, so those " <>
        "columns are not nullable.",
      "AshClickhouse 0.7.3 renders an unconstrained `:decimal` as `Decimal(arbitrary, arbitrary)`, " <>
        "which ClickHouse rejects, so the suite creates those columns as the `Decimal(38, 10)` it documents.",
      "AshClickhouse 0.7.3 does not pass `:username` or `:password` to its client, " <>
        "so the server's default user has no password."
    ]

  def setup! do
    {:ok, _} = Application.ensure_all_started(:hackney)

    opts = AshClickhouse.Repo.config_to_conn_opts(repo())
    database = AshClickhouse.Identifier.quote_name(repo().database())

    # The database must exist before a connection can query in it, so a
    # connection without one recreates it, as `mix ash_clickhouse.setup` does.
    admin = Module.concat(repo(), Admin)

    {:ok, _} =
      AshClickhouse.Connection.start_link(Keyword.merge(opts, name: admin, database: nil))

    AshClickhouse.Connection.query!(admin, "DROP DATABASE IF EXISTS #{database}")
    AshClickhouse.Connection.query!(admin, "CREATE DATABASE #{database}")

    {:ok, _} = AshClickhouse.Connection.start_link(opts)
    Ash.Conformance.Resources.compile!(__MODULE__)

    for role <- Adapter.table_roles() do
      AshClickhouse.Connection.query!(repo(), create_table(resource(role)))
    end

    # Tier-1 tables use AshClickhouse's own generator, without the workarounds
    # above, so what it cannot create shows as that type's failure.
    Ash.Conformance.Storage.provision(__MODULE__, fn type ->
      ddl =
        type.name
        |> Ash.Conformance.Storage.role()
        |> resource()
        |> AshClickhouse.Migration.create_table_cql()

      AshClickhouse.Connection.query!(repo(), ddl)
      [_, column] = Regex.run(~r/^\s*`value` (.+?),?$/m, ddl)
      {:ok, column}
    end)

    :ok
  end

  # AshClickhouse.Migration.create_table_cql/1, except for the two column
  # types described in notes/0.
  defp create_table(resource) do
    columns =
      Enum.map_join(Ash.Resource.Info.attributes(resource), ",\n  ", fn attribute ->
        type =
          case AshClickhouse.DataLayer.Types.resolve_attr_type(attribute) do
            "Decimal(arbitrary, arbitrary)" -> "Decimal(38, 10)"
            type -> type
          end

        composite? = String.starts_with?(type, ["Array", "Map", "Tuple"])
        type = if attribute.allow_nil? and not composite?, do: "Nullable(#{type})", else: type
        "#{AshClickhouse.Identifier.quote_name(attribute.name)} #{type}"
      end)

    order_by =
      case Ash.Resource.Info.primary_key(resource) do
        [] -> "tuple()"
        keys -> Enum.map_join(keys, ", ", &AshClickhouse.Identifier.quote_name/1)
      end

    table = AshClickhouse.Identifier.quote_name(AshClickhouse.DataLayer.source(resource))
    "CREATE TABLE #{table} (\n  #{columns}\n) ENGINE = MergeTree() ORDER BY (#{order_by})"
  end

  def checkout!, do: checkin!()

  def checkin! do
    for role <- Adapter.table_roles() ++ Ash.Conformance.Storage.roles() do
      table = AshClickhouse.Identifier.quote_name(AshClickhouse.DataLayer.source(resource(role)))
      AshClickhouse.Connection.query!(repo(), "TRUNCATE TABLE IF EXISTS #{table}")
    end

    :ok
  end
end

defmodule Ash.Conformance.ClickhouseRepo do
  @moduledoc false
  use AshClickhouse.Repo, otp_app: :ash_conformance
  # The ClickHouse client's specs make Dialyzer conclude a query can only
  # fail, which it reports in the generated ping/0 and query!/3.
  @dialyzer {:nowarn_function, ping: 0, query!: 3}
end
