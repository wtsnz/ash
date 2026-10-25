# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Edges do
  @moduledoc """
  Functions and operators on unusual values (`Ash.Conformance.Fixtures.Edges`),
  where an implementation that works on ordinary values can still be wrong:

  | id | s | strs | ints | i | j | f | d | m | at |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 11 | "été", accents decomposed | [""] | [] | 9223372036854775807 | 1 | 0.5 | 1 | %{"k" => nil} | 2024-03-01 00:00 |
  | 12 | "  \\t padded \\n " | ["a", "", "b"] | [-1, 0, 1] | -7 | 3 | 2.5 | -2.5 | %{} | 2000-01-01 00:00 |
  | 13 | 👩‍👩‍👧, three emoji and two joiners | nil | nil | nil | nil | -2.5 | 0.125 | nil | nil |

  Answers follow the expressions guide and Elixir: no Unicode normalization
  (decomposed "é" is two codepoints and doesn't contain the composed one),
  `string_length` counts codepoints unless asked for graphemes or bytes,
  `string_trim` trims all whitespace as `String.trim/1` does, a negative index
  counts from the end as `Enum.at/2` does, integers don't overflow, `rem`
  keeps the dividend's sign, and `round` rounds half away from zero. The
  signature tier's unit test checks them against Ash's evaluation too.
  """
  require Ash.Expr
  import Ash.Expr, only: [expr: 1]
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Scenarios.Signatures

  @basis "../documentation/topics/reference/expressions.md"

  def all do
    for {suffix, type, expression, expected} <- cases() do
      opts = [fixture: :edges, requires: Signatures.requires(expression), semantic_basis: @basis]
      run = Signatures.calculated(type, expression)
      new("edge.#{suffix}", :expressions, by_row(expected), run, opts)
    end
  end

  def ids, do: Enum.map(cases(), &"edge.#{elem(&1, 0)}")

  defp by_row(:unresolved), do: :unresolved
  defp by_row(values), do: Map.new(Enum.zip(11..13, Enum.map(values, &Signatures.project/1)))

  defp cases do
    [
      # Codepoints by default (`Ash.Query.Function.StringLength`; this suite sets
      # `default_string_length_count: :codepoints`), though the expressions guide
      # still describes `String.length/1`. Graphemes only where Elixir evaluates.
      {"string_length.default", :integer, expr(string_length(s)), [5, 13, 5]},
      {"string_length.graphemes", :integer, expr(string_length(s, :graphemes)), [3, 13, 1]},
      {"string_length.codepoints", :integer, expr(string_length(s, :codepoints)), [5, 13, 5]},
      {"string_length.bytes", :integer, expr(string_length(s, :bytes)), [7, 13, 18]},
      {"string_trim.whitespace", :string, expr(string_trim(s)), ["été", "padded", "👩‍👩‍👧"]},
      {"contains.normalization", :boolean, expr(contains(s, "é")), [false, false, false]},
      {"string_split.empty_items", {:array, :string}, expr(string_split(s, " ")),
       [["été"], ["", "", "\t", "padded", "\n", ""], ["👩‍👩‍👧"]]},
      {"string_join.empty_items", :string, expr(string_join(strs, "-")), ["", "a--b", nil]},
      # Open decisions (`at-negative-index`, `integer-overflow`): no answer yet.
      {"at.negative_index", :integer, expr(at(ints, -1)), :unresolved},
      {"plus.integer_overflow", :integer, expr(i + j), :unresolved},
      {"rem.negative", :integer, expr(rem(i, j)), [0, -1, nil]},
      {"div.negative", :float, expr(i / 2), [4_611_686_018_427_387_904.0, -3.5, nil]},
      {"round.half", :float, expr(round(f)), [1.0, 3.0, -3.0]},
      {"round.decimal_half", :decimal, expr(round(d, 2)),
       [Decimal.new("1"), Decimal.new("-2.5"), Decimal.new("0.13")]},
      {"is_nil.map", :boolean, expr(is_nil(m)), [false, false, true]},
      {"datetime_add.leap_day", :utc_datetime_usec, expr(datetime_add(at, -1, :day)),
       [~U[2024-02-29 00:00:00Z], ~U[1999-12-31 00:00:00Z], nil]}
    ]
  end
end
