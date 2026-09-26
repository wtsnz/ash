# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Records do
  @moduledoc """
  The `record` role: one resource with the common Ash attribute types, used for
  the basic read, write, type, filter, sort and pagination scenarios.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    record = Module.concat(namespace, Record)
    identity_opts = Ash.Conformance.Resources.Base.identity_options(adapter)

    quote context: Elixir do
      defmodule unquote(record) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter), table: "dc_records"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:code, :string, allow_nil?: false, public?: true)

          attribute(:name, :string,
            public?: true,
            constraints: [trim?: false, allow_empty?: true]
          )

          attribute(:quantity, :integer, public?: true)
          attribute(:price, :decimal, public?: true)
          attribute(:ratio, :float, public?: true)
          attribute(:active, :boolean, public?: true)

          attribute(:status, :atom,
            public?: true,
            constraints: [one_of: [:draft, :live, :archived]]
          )

          attribute(:born_on, :date, public?: true)
          attribute(:seen_at, :utc_datetime_usec, public?: true)
          attribute(:opens_at, :time, public?: true)
          attribute(:external_id, :uuid, public?: true)

          attribute(:tags, {:array, :string},
            public?: true,
            constraints: [items: [trim?: false, allow_empty?: true]]
          )

          attribute(:metadata, :map, public?: true)
          attribute(:address, Ash.Conformance.Resources.Address, public?: true)
        end

        identities do
          identity(:code, [:code], unquote(identity_opts))
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :paged do
            pagination(offset?: true, keyset?: true, countable: true, required?: false)
          end

          # Keyset only: with both kinds allowed, a request with only a limit
          # returns offset pages.
          read :keyset_paged do
            pagination(keyset?: true, countable: true, required?: false)
          end

          read :streamable do
            pagination(keyset?: true, required?: false)
          end
        end

        calculations do
          calculate(:double_quantity, :integer, expr(quantity * 2), public?: true)
          calculate(:lower_name, :string, expr(string_downcase(name)), public?: true)

          calculate :suffixed, :string, expr(name <> ^arg(:suffix)) do
            public?(true)
            argument(:suffix, :string, allow_nil?: false)
          end
        end
      end
    end
  end
end
