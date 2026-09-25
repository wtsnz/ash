# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Base do
  @moduledoc false

  @doc """
  Identity options for an adapter, from its `identity_options/0` if defined,
  for example `[pre_check?: true]` where storage cannot enforce uniqueness.
  """
  def identity_options(adapter) when adapter in [:sqlite, :postgres], do: []

  def identity_options(module) do
    Code.ensure_compiled!(module)

    if function_exported?(module, :identity_options, 0),
      do: module.identity_options(),
      else: []
  end

  @doc """
  How resources refer to an adapter: SQLite and Postgres by atom, every other
  adapter by its module, which supplies `resource_config/1`.
  """
  def adapter_ref(adapter) do
    if function_exported?(adapter, :resource_config, 1), do: adapter, else: adapter.id()
  end

  defmacro __using__(opts) do
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    table = Keyword.fetch!(opts, :table)
    authorizers = Keyword.get(opts, :authorizers, [])

    {data_layer, config} =
      case adapter do
        :sqlite ->
          {AshSqlite.DataLayer,
           quote do
             sqlite do
               table(unquote(table))
               repo(Ash.Conformance.SqliteRepo)
             end
           end}

        :postgres ->
          {AshPostgres.DataLayer,
           quote do
             postgres do
               table(unquote(table))
               repo(Ash.Conformance.PostgresRepo)
             end
           end}

        # Any other adapter supplies its data layer and configuration block
        # for each shared table.
        module ->
          module.resource_config(table)
      end

    quote do
      use Ash.Resource,
        domain: Ash.Conformance.Resources.Domain,
        data_layer: unquote(data_layer),
        authorizers: unquote(authorizers)

      unquote(config)

      actions do
        defaults([:read])
      end
    end
  end
end
