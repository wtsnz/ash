# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Base do
  @moduledoc false

  @doc """
  Identity options for an adapter, from its `identity_options/0`, for example
  `[pre_check?: true]` where storage cannot enforce uniqueness.
  """
  def identity_options(adapter) do
    Code.ensure_compiled!(adapter)
    adapter.identity_options()
  end

  defmacro __using__(opts) do
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    table = Keyword.fetch!(opts, :table)
    authorizers = Keyword.get(opts, :authorizers, [])

    # The adapter supplies its data layer and configuration block for each
    # shared table.
    {data_layer, config} = adapter.resource_config(table)

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
