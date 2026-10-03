# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Edges do
  @moduledoc """
  Three rows of unusual values for `Ash.Conformance.Scenarios.Edges`, in the
  signature table: decomposed Unicode, mixed whitespace and an emoji sequence;
  empty and short arrays; the largest integer; halves to round; a map holding
  a null key; a leap day.
  """

  def rows do
    [
      %{
        id: 11,
        # "été" with each accent as a separate combining character (U+0301).
        s: "été",
        strs: [""],
        ints: [],
        i: 9_223_372_036_854_775_807,
        j: 1,
        f: 0.5,
        d: Decimal.new("1"),
        m: %{"k" => nil},
        at: ~U[2024-03-01 00:00:00Z]
      },
      %{
        id: 12,
        s: "  \t padded \n ",
        strs: ["a", "", "b"],
        ints: [-1, 0, 1],
        i: -7,
        j: 3,
        f: 2.5,
        d: Decimal.new("-2.5"),
        m: %{},
        at: ~U[2000-01-01 00:00:00Z]
      },
      # A family: three emoji joined by two zero-width joiners (U+200D).
      %{id: 13, s: "👩‍👩‍👧", f: -2.5, d: Decimal.new("0.125")}
    ]
  end

  def seed!(adapter) do
    Ash.Conformance.Fixtures.seed!(adapter, :sig_row, Ash.Conformance.Fixtures.ordered(rows()))
    %{adapter: adapter}
  end
end
