# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.WriteResources do
  @moduledoc "A ledger role for transaction scenarios: one action fails after its insert."

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = Keyword.fetch!(opts, :adapter)
    ledger = Module.concat(namespace, Ledger)

    quote context: Elixir do
      defmodule unquote(ledger) do
        use Ash.Conformance.Resource, adapter: unquote(adapter), table: "dc_ledger"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:amount, :integer, public?: true)
        end

        actions do
          create :create do
            primary?(true)
            accept([:id, :amount])
          end

          create :create_then_fail do
            accept([:id, :amount])

            change(fn changeset, _context ->
              Ash.Changeset.after_action(changeset, fn _changeset, _record ->
                {:error, "rejected after insert"}
              end)
            end)
          end
        end
      end
    end
  end
end

defmodule Ash.Conformance.SqliteWriteResources do
  @moduledoc false
  use Ash.Conformance.WriteResources, namespace: Ash.Conformance.Sqlite, adapter: :sqlite
end

defmodule Ash.Conformance.PostgresWriteResources do
  @moduledoc false
  use Ash.Conformance.WriteResources, namespace: Ash.Conformance.Postgres, adapter: :postgres
end
