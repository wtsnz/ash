# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Large do
  @moduledoc "The large fixture's resource (`lg_rows`): an id, a value and a label."

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)

    quote context: Elixir do
      defmodule unquote(Module.concat(namespace, LargeRow)) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "lg_rows"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:value, :integer, public?: true)
          attribute(:label, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :paged do
            pagination(offset?: true, countable: true, required?: false)
          end

          read :keyset_paged do
            pagination(keyset?: true, required?: false)
          end
        end
      end
    end
  end
end
