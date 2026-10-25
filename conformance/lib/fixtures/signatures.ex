# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Signatures do
  @moduledoc """
  Three rows for the signature scenarios: ordinary values, edge values (empty
  strings and lists, zero, negatives, 29 February and the last second of a
  day), and nil in every column.
  """

  def rows do
    [
      %{
        id: 1,
        s: "Hello World",
        c: "HeLLo",
        i: 7,
        j: 3,
        f: 2.5,
        d: Decimal.new("2.345"),
        day: ~D[2024-01-31],
        at: ~U[2024-01-31 10:30:00.123456Z],
        sec: ~U[2024-01-31 10:30:00Z],
        dt: ~U[2024-01-31 10:30:00Z],
        naive: ~N[2024-01-31 10:30:00],
        tm: ~T[10:30:00],
        tmu: ~T[10:30:00.123456],
        strs: ["a", "b", "c"],
        ints: [1, 2, 2, 3],
        m: %{"k" => "v", "nested" => %{"x" => 1}},
        flag: true
      },
      %{
        id: 2,
        s: "",
        c: "",
        i: 0,
        j: -2,
        f: -1.5,
        d: Decimal.new("-0.5"),
        day: ~D[2024-02-29],
        at: ~U[2024-02-29 23:59:59.999999Z],
        sec: ~U[2024-02-29 23:59:59Z],
        dt: ~U[2024-02-29 23:59:59Z],
        naive: ~N[2024-02-29 23:59:59],
        tm: ~T[23:59:59],
        tmu: ~T[23:59:59.999999],
        strs: [],
        ints: [],
        m: %{},
        flag: false
      },
      %{id: 3}
    ]
  end

  def seed!(adapter) do
    Ash.Conformance.Fixtures.seed!(adapter, :sig_row, Ash.Conformance.Fixtures.ordered(rows()))
    %{adapter: adapter}
  end
end
