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

    # A resource in a policy variant's set gets that variant's policies,
    # unless it declares its own authorizers (Ash.Conformance.Variant). The
    # decoy set adds its hiding policy to those as well.
    variant = Ash.Conformance.Variant.policy(__CALLER__.module)
    policy = if authorizers == [], do: variant
    own_policies = if authorizers != [], do: Ash.Conformance.Variant.own_policies(variant)
    authorizers = if policy, do: [Ash.Policy.Authorizer], else: authorizers

    # The adapter supplies its data layer and configuration block for each
    # shared table.
    {data_layer, config} = adapter.resource_config(table)

    options =
      [
        domain: Ash.Conformance.Resources.Domain,
        data_layer: data_layer,
        authorizers: authorizers
      ] ++ adapter.resource_options()

    quote do
      use Ash.Resource, unquote(options)

      unquote(config)

      actions do
        defaults([:read])
      end

      unquote(Ash.Conformance.Variant.policies(policy))
      unquote(own_policies)

      @doc false
      def __conformance_table__, do: unquote(table)
    end
  end
end
