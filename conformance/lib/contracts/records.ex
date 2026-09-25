# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.Records do
  @moduledoc """
  Builders for expectation records, imported by each adapter's expectations.

  A record is `:supported`, or `{status, signature, "GAPS.md#gap"}` where the
  signature pins exactly what the adapter does instead: an error class and
  message pattern, a wrong value, or a value per seed order.
  """

  def task(gap), do: "GAPS.md##{gap}"

  @doc "A documented rejection."
  def unsupported(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:unsupported, {:error, exception, pattern}, task(gap)}

  @doc "A defect that raises."
  def defect_error(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:known_defect, {:error, exception, pattern}, task(gap)}

  @doc "A defect that returns a wrong value."
  def defect_value(value, gap), do: {:known_defect, {:value, value}, task(gap)}

  @doc "A wrong answer that changes with the order rows were stored in."
  def defect_orders(values, gap),
    do:
      {:known_defect,
       {:order_dependent, Map.new(values, fn {order, value} -> {order, {:value, value}} end)},
       task(gap)}

  @doc "The observation for a scenario whose intended answer awaits a decision."
  def unresolved_value(value, gap), do: {:unresolved, {:value, value}, task(gap)}

  def unresolved_error(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:unresolved, {:error, exception, pattern}, task(gap)}
end
