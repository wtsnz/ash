# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:city, :string, public?: true)
    attribute(:zip, :string, public?: true)
  end
end

defmodule Ash.Conformance.RecordResources do
  @moduledoc """
  The `record` role: one resource with the common Ash attribute types, used for
  the basic read, write, type, filter, sort and pagination scenarios.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = Keyword.fetch!(opts, :adapter)
    record = Module.concat(namespace, Record)
    # ETS cannot enforce uniqueness itself, so Ash checks the identity first.
    identity_opts = if adapter == :ets, do: [pre_check?: true], else: []

    quote context: Elixir do
      defmodule unquote(record) do
        use Ash.Conformance.Resource, adapter: unquote(adapter), table: "dc_records"

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
          attribute(:address, Ash.Conformance.Address, public?: true)
        end

        identities do
          identity(:code, [:code], unquote(identity_opts))
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :paged do
            pagination(offset?: true, keyset?: true, countable: true, required?: false)
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

defmodule Ash.Conformance.SqliteRecordResources do
  @moduledoc false
  use Ash.Conformance.RecordResources, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
end

defmodule Ash.Conformance.PostgresRecordResources do
  @moduledoc false
  use Ash.Conformance.RecordResources, namespace: Ash.Conformance.Postgres, adapter: :postgres
end

defmodule Ash.Conformance.EtsRecordResources do
  @moduledoc false
  use Ash.Conformance.RecordResources, namespace: Ash.Conformance.Ets, adapter: :ets
end
