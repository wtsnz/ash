# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Signatures do
  @moduledoc """
  The signature fixture's resource (`sig_rows`): one column per argument type
  Ash's functions and operators declare, for
  `Ash.Conformance.Scenarios.Signatures`.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    module = Module.concat(namespace, SigRow)

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "sig_rows"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:s, :string, constraints: [trim?: false, allow_empty?: true], public?: true)

          attribute(:c, :ci_string,
            constraints: [trim?: false, allow_empty?: true],
            public?: true
          )

          attribute(:i, :integer, public?: true)
          attribute(:j, :integer, public?: true)
          attribute(:f, :float, public?: true)
          attribute(:d, :decimal, public?: true)
          attribute(:day, :date, public?: true)
          attribute(:at, :utc_datetime_usec, public?: true)
          attribute(:sec, :utc_datetime, public?: true)
          attribute(:dt, :datetime, public?: true)
          attribute(:naive, :naive_datetime, public?: true)
          attribute(:tm, :time, public?: true)
          attribute(:tmu, :time_usec, public?: true)

          attribute(:strs, {:array, :string},
            constraints: [items: [trim?: false, allow_empty?: true]],
            public?: true
          )

          attribute(:ints, {:array, :integer}, public?: true)
          attribute(:m, :map, public?: true)
          attribute(:flag, :boolean, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end
      end
    end
  end
end
