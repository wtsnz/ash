# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Compare do
  @moduledoc """
  Strict structural equality for observed results.

  Elixir's `==` treats `2` and `2.0` as equal, so a result whose type changed
  from integer to float would still pass. Here numbers must also match in type,
  recursively through lists, tuples, maps and structs.

  Decimals compare by value, as Ash's own `Ash.Type.Decimal.equal?/2` does:
  `0.30` is `0.3`, but never the float `0.3`. Whether a changed representation
  counts as stored unchanged is an open Ash decision (`value-representation`
  in `GAPS.md`); tier 1 reports it separately and does not use this rule.
  """

  def equal?(left, right) when is_integer(left) and is_integer(right), do: left == right
  def equal?(left, right) when is_float(left) and is_float(right), do: left == right
  def equal?(left, right) when is_number(left) or is_number(right), do: false

  def equal?(left, right) when is_list(left) and is_list(right),
    do: length(left) == length(right) and Enum.all?(Enum.zip(left, right), &pair_equal?/1)

  def equal?(left, right) when is_tuple(left) and is_tuple(right),
    do: equal?(Tuple.to_list(left), Tuple.to_list(right))

  def equal?(%Decimal{} = left, %Decimal{} = right), do: Decimal.eq?(left, right)

  def equal?(%module{} = left, %module{} = right),
    do: equal?(Map.from_struct(left), Map.from_struct(right))

  def equal?(%_{}, _right), do: false
  def equal?(_left, %_{}), do: false

  def equal?(left, right) when is_map(left) and is_map(right) do
    map_size(left) == map_size(right) and
      Enum.all?(left, fn {key, value} ->
        Enum.any?(right, fn {other_key, other} ->
          equal?(key, other_key) and equal?(value, other)
        end)
      end)
  end

  def equal?(left, right), do: left === right

  defp pair_equal?({left, right}), do: equal?(left, right)
end
