# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Storage do
  @moduledoc """
  One resource per tier-1 type: an integer `id` and a nullable `value`, in its
  own table, so each type is stored and read back in isolation.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)

    definitions =
      for type <- Ash.Conformance.Storage.types() do
        module =
          Module.concat(
            namespace,
            Macro.camelize(to_string(Ash.Conformance.Storage.role(type.name)))
          )

        quote context: Elixir do
          defmodule unquote(module) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: unquote(Ash.Conformance.Storage.table(type.name))

            attributes do
              attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)

              attribute(:value, unquote(Macro.escape(type.type)),
                constraints: unquote(Macro.escape(type.constraints)),
                public?: true
              )
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])
            end
          end
        end
      end

    quote do
      (unquote_splicing(definitions))
    end
  end
end
