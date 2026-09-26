# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Expressions do
  @moduledoc """
  Four rows for expression functions and nil logic. Row 3 is mostly nil;
  row 4 has zero, an empty string and a nil `b` and `t`.
  """

  def rows do
    [
      %{
        id: 1,
        a: 7,
        b: 2,
        f: 1.5,
        d: Decimal.new("2.50"),
        s: "Hello",
        t: "Ünïcode ✓",
        day: ~D[2024-02-28],
        at: ~U[2024-02-28 23:30:00.000000Z]
      },
      %{
        id: 2,
        a: -7,
        b: 3,
        f: -2.5,
        d: Decimal.new("-1.25"),
        s: "  padded  ",
        t: "abc",
        day: ~D[2024-12-31],
        at: ~U[2024-12-31 12:00:00.000000Z]
      },
      %{id: 3, a: nil, b: 4, f: nil, d: nil, s: nil, t: "x", day: nil, at: nil},
      %{
        id: 4,
        a: 0,
        b: nil,
        f: 2.0,
        d: Decimal.new("0.1"),
        s: "",
        t: nil,
        day: ~D[2023-01-31],
        at: ~U[2023-01-31 00:00:00.000000Z]
      }
    ]
  end

  def seed!(adapter) do
    Ash.Conformance.Fixtures.seed!(adapter, :expr_row, Ash.Conformance.Fixtures.ordered(rows()))
    %{adapter: adapter}
  end
end
