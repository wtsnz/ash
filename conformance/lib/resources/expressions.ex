# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Expressions do
  @moduledoc """
  The expression fixture's resource (`ex_rows`): four rows of integers,
  floats, decimals, text, dates and datetimes, some nil, for expression
  functions and nil logic. See `Ash.Conformance.Scenarios.Expressions`.
  """

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    module = Module.concat(namespace, ExprRow)

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "ex_rows"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:a, :integer, public?: true)
          attribute(:b, :integer, public?: true)
          attribute(:f, :float, public?: true)
          attribute(:d, :decimal, public?: true)
          attribute(:s, :string, constraints: [trim?: false, allow_empty?: true], public?: true)
          attribute(:t, :string, constraints: [trim?: false, allow_empty?: true], public?: true)
          attribute(:day, :date, public?: true)
          attribute(:at, :utc_datetime_usec, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end
      end
    end
  end
end
