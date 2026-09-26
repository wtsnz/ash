# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Identities do
  @moduledoc """
  Identities over a nullable key. `identity_row` (`idn_rows`) has the
  default identity, where nil values never conflict; `strict_identity_row`
  (`idx_rows`) sets `nils_distinct?: false`, so they do. Each has an upsert
  on the identity that only updates `value`.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)

    for {role, table, nils_distinct?} <- [
          {:identity_row, "idn_rows", true},
          {:strict_identity_row, "idx_rows", false}
        ] do
      module = Module.concat(namespace, Macro.camelize(to_string(role)))

      identity_opts =
        [nils_distinct?: nils_distinct?] ++
          Ash.Conformance.Resources.Base.identity_options(adapter)

      quote context: Elixir do
        defmodule unquote(module) do
          use Ash.Conformance.Resources.Base,
            adapter: unquote(adapter),
            table: unquote(table)

          attributes do
            attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
            attribute(:code, :string, allow_nil?: false, public?: true)
            attribute(:scope, :string, public?: true)
            attribute(:value, :integer, public?: true)
            attribute(:note, :string, public?: true)
          end

          identities do
            identity(:code_scope, [:code, :scope], unquote(identity_opts))
          end

          actions do
            defaults([:read, :destroy, create: :*, update: :*])

            create :upsert do
              accept([:id, :code, :scope, :value, :note])
              upsert?(true)
              upsert_identity(:code_scope)
              upsert_fields([:value])
            end
          end
        end
      end
    end
  end
end
